const std = @import("std");

const Thread = std.Thread;
const atomic = std.atomic;

const midi = @import("../util/midi.zig");
const c = @import("color.zig");

const LedFlags = c.LedFlags;
const Color = c.Color;

const LaunchpadKey = @import("key.zig").LaunchpadKey;

const eq = @import("../util/event_queue.zig");
const EventQueue = eq.EventQueue;
const InputEvent = eq.InputEvent;

const MidiDevice = midi.MidiDevice;
const Position = @import("../util/position.zig").Position;
const MidiMessage = @import("../util/midi_message.zig").MidiMessage;

pub const NamedKey = enum(u4) {
    VOL,
    PAN,
    SND_A,
    SND_B,
    STOP,
    TRK_ON,
    SOLO,
    ARM,
    UP,
    DOWN,
    LEFT,
    RIGHT,
    SESSION,
    USER1,
    USER2,
    MIXER,
};

pub const LaunchpadConfig = struct {
    event_queue_size: usize = 256,
    input_timeout_ms: u64 = 10,
};

pub const Launchpad = struct {
    device: MidiDevice,
    allocator: std.mem.Allocator,
    config: LaunchpadConfig,

    event_queue: EventQueue,
    input_thread: ?Thread,
    should_stop: atomic.Value(bool),

    const Self = @This();

    const GRID_SIZE: comptime_int = 64;
    const GRID_WIDTH: comptime_int = 8;
    const GRID_HEIGHT: comptime_int = 8;

    const grid_keys = blk: {
        var arr: [GRID_SIZE]LaunchpadKey = undefined;
        for (0..GRID_SIZE) |i| {
            const row = i / GRID_WIDTH;
            const col = i % GRID_WIDTH;
            arr[i] = .{ .command = 0x90, .note = @as(u8, @intCast(row * 16 + col)) };
        }
        break :blk arr;
    };

    const namedkey_map = std.enums.EnumMap(NamedKey, LaunchpadKey).init(.{
        .VOL = .{ .command = 0x90, .note = 8 },
        .PAN = .{ .command = 0x90, .note = 24 },
        .SND_A = .{ .command = 0x90, .note = 40 },
        .SND_B = .{ .command = 0x90, .note = 56 },
        .STOP = .{ .command = 0x90, .note = 72 },
        .TRK_ON = .{ .command = 0x90, .note = 88 },
        .SOLO = .{ .command = 0x90, .note = 104 },
        .ARM = .{ .command = 0x90, .note = 120 },
        .UP = .{ .command = 0xB0, .note = 104 },
        .DOWN = .{ .command = 0xB0, .note = 105 },
        .LEFT = .{ .command = 0xB0, .note = 106 },
        .RIGHT = .{ .command = 0xB0, .note = 107 },
        .SESSION = .{ .command = 0xB0, .note = 108 },
        .USER1 = .{ .command = 0xB0, .note = 109 },
        .USER2 = .{ .command = 0xB0, .note = 110 },
        .MIXER = .{ .command = 0xB0, .note = 111 },
    });

    pub fn init(allocator: std.mem.Allocator, config: LaunchpadConfig) !Self {
        const device = try midi.chooseMidiDevice(allocator);
        return .{
            .device = device,
            .allocator = allocator,
            .config = config,
            .event_queue = try EventQueue.init(allocator, config.event_queue_size),
            .input_thread = null,
            .should_stop = atomic.Value(bool).init(false),
        };
    }

    pub fn setupInputs(self: *Self) !void {
        std.log.info("Starting input thread. EventQueue addr: {*}", .{ &self.event_queue });
        _ = try Thread.spawn(.{}, inputThreadFn, .{ self });
    }

    pub fn deinit(self: *Self) void {
        self.should_stop.store(true, .monotonic);
        if (self.input_thread) |thread| {
            thread.join();
        }
        self.event_queue.shutdown();
        self.event_queue.deinit();
        self.allocator.free(self.device.path);
        self.device.deinit();
    }

    fn inputThreadFn(self: *Self) void {
        std.log.info("Input thread started", .{});
        var buf: [3]u8 = undefined;
        while (!self.should_stop.load(.monotonic)) {
            if (self.device.readNonBlocking(buf[0..], @intCast(self.config.input_timeout_ms))) |bytes_read| {
                if (bytes_read == 3) {
                    const message = MidiMessage.fromBytes(buf);
                    std.log.debug("MIDI message: cmd={x}, note={}, vel={}", .{
                        message.command, message.note, message.velocity 
                    });
                    const event = InputEvent.init(message);
                    self.event_queue.push(event) catch |err| {
                        std.log.warn("Failed to queue input event: {}", .{err});
                    };
                    std.log.debug("Queue size after push: {}", .{self.event_queue.size});
                } else if (bytes_read != null and bytes_read.? > 0) {
                    std.log.warn("Unexpected MIDI data size: {any} bytes", .{bytes_read});
                }
            } else |err| {
                if (err != error.WouldBlock) {
                    std.log.warn("MIDI read error: {}", .{err});
                }
            }
            std.time.sleep(100_000); // 0.1ms
        }
        std.log.info("Input thread stopping", .{});
    }

    pub fn getGridKey(index: usize) !LaunchpadKey {
        if (index >= GRID_SIZE) {
            return error.KeyOutOfBounds;
        }
        return grid_keys[index];
    }

    pub fn getGridKeyAt(pos: Position) !LaunchpadKey {
        if (!pos.isValid()) return error.KeyOutOfBounds;
        return grid_keys[pos.toGridIndex()];
    }

    pub fn getNamedKey(key: NamedKey) LaunchpadKey {
        return namedkey_map.get(key).?;
    }

    pub fn setLight(self: *Self, key: LaunchpadKey, color: LedFlags) !void {
        const message = key.toBytes(color.toVelocity());
        try self.device.write(&message);
    }

    pub fn setGridLight(self: *Self, index: usize, color: LedFlags) !void {
        const key = try Launchpad.getGridKey(index);
        try self.setLight(key, color);
    }

    pub fn clearLightsGrid(self: *Self) !void {
        for (0..GRID_SIZE) |i| {
            try self.setGridLight(i, Color.OFF);
        }
    }

    pub fn clearLightsTools(self: *Self) !void {
        const keyNames = std.EnumSet(NamedKey).initFull();
        var iter = keyNames.iterator();
        while (iter.next()) |key| {
            try self.setLight(Launchpad.getNamedKey(key), Color.OFF);
        }
    }

    pub fn clearLightsAll(self: *Self) !void {
        try self.clearLightsGrid();
        try self.clearLightsTools();
    }

    pub fn reset(self: *Self) !void {
        try self.device.write(&.{ 0xB0, 0x00, 0x00 });
    }

    pub fn pollEvent(self: *Self) ?InputEvent {
        return self.event_queue.pop();
    }

    pub fn waitForEvent(self: *Self, timeout_ms: u64) ?InputEvent {
        return self.event_queue.waitForEvent(timeout_ms);
    }

    pub fn drainEvents(self: *Self, buffer: []InputEvent) usize {
        return self.event_queue.drain(buffer);
    }
};
