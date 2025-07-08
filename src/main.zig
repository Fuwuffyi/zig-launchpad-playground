const std = @import("std");
const fs = std.fs;

const Launchpad = @import("launchpad/launchpad.zig").Launchpad;

pub fn main() !void {
    // Create allocator
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    // Initialize launchpad
    var launchpad = try Launchpad.init(allocator);
    // Run loop to get messages
    var should_stop: bool = false;
    while (!should_stop) {
        if (try launchpad.readMessage()) |message| {
            // Skip unpressed events
            if (!message.isPressed()) continue;
            // Stop on mixer key press
            if (message.matchesKey(Launchpad.getNamedKey(.MIXER))) {
                should_stop = true;
            }
            // Clear on VOL press
            if (message.matchesKey(Launchpad.getNamedKey(.VOL))) {
                try launchpad.clearGridLights();
            }
        }
    }
}
