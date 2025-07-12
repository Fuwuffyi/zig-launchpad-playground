pub const Position = struct {
    x: u8,
    y: u8,

    const Self = @This();

    pub fn init(x: u8, y: u8) Self {
        return .{ .x = x, .y = y };
    }

    pub fn equals(self: Self, other: Self) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn toGridIndex(self: Self) usize {
        return self.x + self.y * 8;
    }

    pub fn fromGridIndex(index: usize) Self {
        return .{
            .x = @intCast(index % 8),
            .y = @intCast(index / 8),
        };
    }

    pub fn isValid(self: Self) bool {
        return self.x < 8 and self.y < 8;
    }

    pub fn moveUp(self: Self) Self {
        return .{ .x = self.x, .y = if (self.y > 0) self.y - 1 else 0 };
    }

    pub fn moveDown(self: Self) Self {
        return .{ .x = self.x, .y = if (self.y < 7) self.y + 1 else 7 };
    }

    pub fn moveLeft(self: Self) Self {
        return .{ .x = if (self.x > 0) self.x - 1 else 0, .y = self.y };
    }

    pub fn moveRight(self: Self) Self {
        return .{ .x = if (self.x < 7) self.x + 1 else 7, .y = self.y };
    }
};

