const std = @import("std");
const fs = std.fs;

const l = @import("launchpad/launchpad.zig");
const Launchpad = l.Launchpad;
const LaunchpadConfig = l.LaunchpadConfig;

const Color = @import("launchpad/color.zig").Color;

const Position = @import("util/position.zig").Position;

const InputEvent = @import("util/event_queue.zig").InputEvent;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var launchpad = try Launchpad.init(allocator, LaunchpadConfig{
        .event_queue_size = 256,
        .input_timeout_ms = 10,
    });
    defer launchpad.deinit();
    try launchpad.reset();
    try launchpad.setLight(Launchpad.getNamedKey(.MIXER), Color.RED_HIGH);
    try launchpad.setupInputs();
    while (!launchpad.should_stop.load(.monotonic)) {
        var event_buf: [64]InputEvent = undefined;
        const event_count = launchpad.drainEvents(&event_buf);
        for (0..event_count) |idx| {
            const evt = event_buf[idx];
            const message = evt.message;
            if (message.matchesKey(Launchpad.getNamedKey(.MIXER)) and message.isPressed()) {
                launchpad.should_stop.store(true, .monotonic);
                launchpad.event_queue.shutdown();
            }
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
