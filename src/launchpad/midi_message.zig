const k = @import("key.zig");

const LaunchpadKey = k.LaunchpadKey;

pub const MidiMessage = struct {
    command: u8,
    note: u8,
    velocity: u8,

    const Self = @This();

    pub fn fromBytes(bytes: [3]u8) Self {
        return .{
            .command = bytes[0] & 0xF0,
            .note = bytes[1],
            .velocity = bytes[2]
        };
    }

    pub fn getChannel(self: Self) u8 {
        return self.command & 0x0F;
    }

    pub fn isPressed(self: Self) bool {
        return self.velocity > 0;
    }

    pub fn matchesKey(self: Self, key: LaunchpadKey) bool {
        return key.equalsRaw(self.note, self.command);
    }
};
