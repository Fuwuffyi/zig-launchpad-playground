pub const LedFlags = packed struct {
    red: LedBrightness,
    copy: bool,
    clear: bool,
    green: LedBrightness,
    _reserved: u1 = 0,

    pub fn toVelocity(self: LedFlags) u8 {
        return @as(u8, @intFromEnum(self.red)) |
            (@as(u8, @intFromBool(self.copy)) << 2) |
            (@as(u8, @intFromBool(self.clear)) << 3) |
            (@as(u8, @intFromEnum(self.green)) << 4);
    }
};

pub const LedBrightness = enum(u2) {
    OFF = 0,
    LOW = 1,
    MEDIUM = 2,
    FULL = 3,
};

// Color velocity values
pub const Color = struct {
    pub const OFF = LedFlags{ .red = .OFF, .green = .OFF, .copy = true, .clear = true };
    pub const RED_LOW = LedFlags{ .red = .LOW, .green = .OFF, .copy = true, .clear = true };
    pub const RED_MED = LedFlags{ .red = .MEDIUM, .green = .OFF, .copy = true, .clear = true };
    pub const RED_HIGH = LedFlags{ .red = .FULL, .green = .OFF, .copy = true, .clear = true };
    pub const GREEN_LOW = LedFlags{ .red = .OFF, .green = .LOW, .copy = true, .clear = true };
    pub const GREEN_MED = LedFlags{ .red = .OFF, .green = .MEDIUM, .copy = true, .clear = true };
    pub const GREEN_HIGH = LedFlags{ .red = .OFF, .green = .FULL, .copy = true, .clear = true };
    pub const AMBER_LOW = LedFlags{ .red = .LOW, .green = .LOW, .copy = true, .clear = true };
    pub const AMBER_MED = LedFlags{ .red = .MEDIUM, .green = .MEDIUM, .copy = true, .clear = true };
    pub const AMBER_HIGH = LedFlags{ .red = .FULL, .green = .FULL, .copy = true, .clear = true };
    pub const YELLOW_HIGH = LedFlags{ .red = .FULL, .green = .MEDIUM, .copy = true, .clear = true };
    // Flash colors (for manual flashing control)
    pub const FLASH_RED_LOW= LedFlags{ .red = .LOW, .green = .OFF, .copy = false, .clear = false };
    pub const FLASH_RED_MED= LedFlags{ .red = .MEDIUM, .green = .OFF, .copy = false, .clear = false };
    pub const FLASH_RED_HIGH = LedFlags{ .red = .FULL, .green = .OFF, .copy = false, .clear = false };
    pub const FLASH_GREEN_LOW= LedFlags{ .red = .OFF, .green = .LOW, .copy = false, .clear = false };
    pub const FLASH_GREEN_MED= LedFlags{ .red = .OFF, .green = .MEDIUM, .copy = false, .clear = false };
    pub const FLASH_GREEN_HIGH = LedFlags{ .red = .OFF, .green = .FULL, .copy = false, .clear = false };
    pub const FLASH_AMBER_LOW= LedFlags{ .red = .LOW, .green = .LOW, .copy = false, .clear = false };
    pub const FLASH_AMBER_MED= LedFlags{ .red = .MEDIUM, .green = .MEDIUM, .copy = false, .clear = false };
    pub const FLASH_AMBER_HIGH = LedFlags{ .red = .FULL, .green = .FULL, .copy = false, .clear = false };
    pub const FLASH_YELLOW_HIGH = LedFlags{ .red = .FULL, .green = .MEDIUM, .copy = false, .clear = false };
};
