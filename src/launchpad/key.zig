const std = @import("std");

pub const LaunchpadKey = struct {
    command: u8,
    note: u8,

    const Self = @This();

    pub fn equals(self: Self, other: Self) bool {
        return self.command == other.command and self.note == other.note;
    }

    pub fn equalsRaw(self: Self, note: u8, command: u8) bool {
        return self.command == command and self.note == note;
    }

    pub fn toBytes(self: Self, velocity: u8) [3]u8 {
        return .{ self.command, self.note, velocity };
    }
};

