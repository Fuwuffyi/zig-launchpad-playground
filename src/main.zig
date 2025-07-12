const std = @import("std");
const fs = std.fs;

const Launchpad = @import("launchpad/launchpad.zig").Launchpad;
const Color = @import("launchpad/color.zig").Color;

const Position = @import("util/position.zig").Position;

pub fn main() !void {
    // Create allocator
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    // Initialize launchpad
    var launchpad = try Launchpad.init(allocator);
    try launchpad.reset();
    // Light up utility buttons
    try launchpad.setLight(Launchpad.getNamedKey(.MIXER), Color.RED_HIGH);
    // Run loop to get messages
    var should_stop: bool = false;
    while (!should_stop) {
        if (try launchpad.readMessage()) |message| {
            // Stop on mixer key press
            if (message.matchesKey(Launchpad.getNamedKey(.MIXER)) and message.isPressed()) {
                should_stop = true;
            }
            // Basic input testing
            for (0..64) |i| {
                const k = try Launchpad.getGridKey(i);
                if (message.matchesKey(k) and message.isPressed()) {
                    try launchpad.setLight(k, Color.AMBER_MED);
                } else if (message.matchesKey(k) and !message.isPressed()) {
                    try launchpad.setLight(k, Color.OFF);
                }
            }
        }
        std.time.sleep(16_666_667); // ~60FPS
    }
    try launchpad.reset();
}
