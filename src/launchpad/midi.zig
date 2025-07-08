const std = @import("std");
const fs = std.fs;
const os = std.os;

const MidiError = error {
    NoMidiDeviceFound,
    NoUserInput,
    InvalidIndexInput,
    IndexOutOfBounds,
    DeviceOpenFailed,
};

pub const MidiDevice = struct {
    file: fs.File,
    path: []const u8,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.file.close();
    }

    pub fn read(self: *const Self, buffer: []u8) !usize {
        return self.file.read(buffer);
    }
    
    pub fn readNonBlocking(self: *const Self, buffer: []u8, timeout_ms: i32) !?usize {
        const fd = self.file.handle;
        var poll_fd = [_]os.linux.pollfd{
            os.linux.pollfd{
                .fd = @intCast(fd),
                .events = os.linux.POLL.IN,
                .revents = 0,
            },
        };
        const poll_result = os.linux.poll(@ptrCast(&poll_fd), 1, timeout_ms);
        if (poll_result == 0) return null;
        if (poll_fd[0].revents & os.linux.POLL.IN != 0) return try self.file.read(buffer);
        return null;
    }

    pub fn write(self: *const Self, data: []const u8) !void {
        return self.file.writeAll(data);
    }
};

pub fn listMidiDevices(allocator: std.mem.Allocator) ![][]u8 {
    // Load up midi directory
    const midi_dir = "/dev/snd/";
    var dir = fs.openDirAbsolute(midi_dir, .{ .iterate = true }) catch |err| switch (err) {
        error.FileNotFound => return MidiError.NoMidiDeviceFound,
        else => return err,
    };
    defer dir.close();
    // Get all devices in midi directory
    var devices = std.ArrayList([]u8).init(allocator);
    defer devices.deinit();
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "midiC")) {
            const device_path = try fs.path.join(allocator, &[_][]const u8{ midi_dir, entry.name });
            try devices.append(device_path);
        }
    }
    return devices.toOwnedSlice();
}

pub fn chooseMidiDevice(allocator: std.mem.Allocator) !MidiDevice {
    // Get all devices
    const devices = try listMidiDevices(allocator);
    defer {
        for (devices) |device| {
            allocator.free(device);
        }
        allocator.free(devices);
    }
    if (devices.len == 0) return MidiError.NoMidiDeviceFound;
    // Display all devices
    std.debug.print("Available MIDI devices:\n", .{});
    for (devices, 0..) |device, idx| {
        std.debug.print("[{}]: {s}\n", .{ idx, device });
    }
    // Get user device choice
    const stdin = std.io.getStdIn().reader();
    std.debug.print("\nEnter index of MIDI device to use: ", .{});
    var line_buf: [4]u8 = undefined;
    const user_input = try stdin.readUntilDelimiterOrEof(&line_buf, '\n') orelse {
        return MidiError.NoUserInput;
    };
    const choice = std.fmt.parseInt(usize, user_input, 4) catch {
        return MidiError.InvalidIndexInput;
    };
    if (choice >= devices.len) return MidiError.IndexOutOfBounds;
    // Clone the path to return
    const selected_path = try allocator.dupe(u8, devices[choice]);
    const file = fs.openFileAbsolute(selected_path, .{ .mode = .read_write }) catch |err| switch (err) {
        else => {
            allocator.free(selected_path);
            return MidiError.DeviceOpenFailed;
        }
    };
    return .{ .file = file, .path = selected_path };
}
