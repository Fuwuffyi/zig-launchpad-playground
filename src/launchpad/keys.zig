const std = @import("std");

const KeyError = error {
    KEY_OUT_OF_BOUNDS,
};

const LaunchpadKey = struct {
    command: u8,
    note: u8,
};

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

pub const Keys = struct {
    const grid_keys = blk: {
        var arr: [64]LaunchpadKey = undefined;
        for (0..64) |i| {
            const row = i / 8;
            const col = i % 8;
            arr[i] = .{ .command = 0x90, .note = row * 16 + col };
        }
        break :blk arr;
    };

    const namedKeyMap = std.enums.EnumMap(NamedKey, LaunchpadKey).init(.{
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

    pub fn getGridKey(index: usize) !LaunchpadKey {
        if (index >= grid_keys.len) return error.KEY_OUT_OF_BOUNDS;
        return grid_keys[index];
    }

    pub fn getNamedKey(key: NamedKey) LaunchpadKey {
        return namedKeyMap.get(key).?;
    }
};
