const std = @import("std");
const fs = std.fs;

pub fn main() !void {
    // Create allocator
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    // Get midi file dir
    var dir: fs.Dir = try fs.openDirAbsolute("/dev/snd/", .{ .iterate = true });
    defer dir.close();
    // Get all midi files
    var midi_entries: std.ArrayList([]u8) = std.ArrayList([]u8).init(allocator);
    defer midi_entries.deinit();
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "midiC")) {
            const file_path: []u8 = try std.fs.path.join(allocator, &[_][]const u8{"/dev/snd", entry.name});
            try midi_entries.append(file_path);
        }
    }
    // Exit if no midi file found
    if (midi_entries.items.len == 0) {
        return;
    }
    // Show the user the midi files
    for (midi_entries.items, 0..) |path, idx| {
        std.debug.print("[{}]: {s}\n", .{ idx, path });
    }
    // Prompt to choose midi file
    const stdin = std.io.getStdIn().reader();
    std.debug.print("\nEnter MIDI device to use (index): ", .{});
    var line_buf: [10]u8 = undefined;
    const user_input = try stdin.readUntilDelimiterOrEof(&line_buf, '\n');
    if (user_input == null) {
        return;
    }
    const choice = std.fmt.parseInt(usize, user_input.?, 10) catch {
        return;
    };
    if (choice >= midi_entries.items.len) {
        return;
    }
    const selected_path = midi_entries.items[choice];
    var file = try fs.openFileAbsolute(selected_path, .{ .mode = fs.File.OpenMode.read_write });
    defer file.close();
    // Start logging keys
    var buf: [3]u8 = undefined;
    while (true) {
        const bytes_read = try file.read(buf[0..]);
        if (bytes_read != 3) {
            continue;
        }
        const status: u8 = buf[0];
        const note: u8 = buf[1];
        const velocity: u8 = buf[2];
        const command: u8 = status & 0xF0;
        const channel: u8 = status & 0x0F;
        std.debug.print("{}\t{}\t{}\t{}\t{}\n", .{ status, note, velocity, command, channel });
    }
}
