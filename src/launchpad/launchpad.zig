const std = @import("std");

const midi = @import("midi.zig");
const k = @import("key.zig");
const midi_msg = @import("midi_message.zig");

const LaunchpadKey = k.LaunchpadKey;
const MidiDevice = midi.MidiDevice;
const MidiMessage = midi_msg.MidiMessage;

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
    USER_ONE,
    USER_TWO,
    MIXER,
};

pub const Color = enum(u8) {
    BLANK = 0x0C,
    DIM_RED = 0x0D,
    BRIGHT_RED = 0x0F,
    DIM_AMBER = 0x1D,
    BRIGHT_AMBER = 0x3F,
    YELLOW = 0x3E,
    DIM_GREEN = 0x1C,
    BRIGHT_GREEN = 0x3C,
};

pub const Launchpad = struct {
    device: MidiDevice,
    allocator: std.mem.Allocator,

    const Self = @This();

    const GRID_SIZE: comptime_int  = 64;
    const GRID_WIDTH: comptime_int  = 8;
    const GRID_HEIGHT: comptime_int = 8;
    
    const grid_keys = blk: {
        var arr: [GRID_SIZE]LaunchpadKey = undefined;
        for (0..GRID_SIZE) |i| {
            const row = i / GRID_WIDTH;
            const col = i % GRID_WIDTH;
            arr[i] = .{ .command = 0x90, .note = row * 16 + col };
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
        .USER_ONE = .{ .command = 0xB0, .note = 109 },
        .USER_TWO = .{ .command = 0xB0, .note = 110 },
        .MIXER = .{ .command = 0xB0, .note = 111 },
    });

    pub fn init(allocator: std.mem.Allocator) !Self {
        const device = try midi.chooseMidiDevice(allocator);
        return .{ .device = device, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.device.path);
        self.device.deinit();
    }

    pub fn readMessage(self: *Self) !?MidiMessage {
        var buf: [3]u8 = undefined;
        if (try self.device.readNonBlocking(buf[0..], 1)) |bytes_read| {
            if (bytes_read == 3) return MidiMessage.fromBytes(buf);
        }
        return null;
    }

    pub fn getGridKey(index: usize) !LaunchpadKey {
        if (index >= GRID_SIZE) {
            return error.KeyOutOfBounds;
        }
        return grid_keys[index];
    }

    pub fn getNamedKey(key: NamedKey) LaunchpadKey {
        return namedkey_map.get(key).?;
    }

    pub fn setLight(self: *Self, key: LaunchpadKey, color: Color) !void {
        const message = key.toBytes(@intFromEnum(color));
        try self.device.write(&message);
    }
    
    pub fn setGridLight(self: *Self, index: usize, color: Color) !void {
        const key = try Launchpad.getGridKey(index);
        try self.setLight(key, color);
    }
    
    pub fn clearLightsGrid(self: *Self) !void {
        for (0..GRID_SIZE) |i| {
            try self.setGridLight(i, Color.BLANK);
        }
    }

    pub fn clearLightsTools(self: *Self) !void {
        const keyNames = std.EnumSet(NamedKey).initFull();
        var iter = keyNames.iterator();
        while (iter.next()) |key| {
            try self.setLight(Launchpad.getNamedKey(key), Color.BLANK);
        }
    }

    pub fn clearLightsAll(self: *Self) !void {
        try self.clearLightsGrid();
        try self.clearLightsTools();
    }
};
