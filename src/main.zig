const std = @import("std");
const fs = std.fs;

const l_midi = @import("launchpad/midi.zig");
const l_key = @import("launchpad/key.zig");
const l_launchpad= @import("launchpad/launchpad.zig");

const Launchpad = l_launchpad.Launchpad;

pub fn main() !void {
    // Create allocator
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    // Initialize launchpad
    var launchpad = try Launchpad.init(allocator);
    // Setup position variables
    var p_x: u8 = 0;
    var p_y: u8 = 0;
    var x: u8 = 0;
    var y: u8 = 0;
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
            // On arrow keys
            if (message.matchesKey(Launchpad.getNamedKey(.UP))) {
                if (y > 0) y -= 1;
            }
            if (message.matchesKey(Launchpad.getNamedKey(.DOWN))) {
                if (y < 7) y += 1;
            }
            if (message.matchesKey(Launchpad.getNamedKey(.LEFT))) {
                if (x > 0) x -= 1;
            }
            if (message.matchesKey(Launchpad.getNamedKey(.RIGHT))) {
                if (x < 7) x += 1;
            }
            if (x == p_x and y == p_y) continue;
            try launchpad.setGridLight(p_x + p_y * 8, 0);
            try launchpad.setGridLight(x + y * 8, 45);
            p_y = y;
            p_x = x;
        }
    }
}
