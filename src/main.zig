const std = @import("std");
const fs = std.fs;

const launchpad_keys = @import("launchpad/keys.zig");
const NamedKey = launchpad_keys.NamedKey;
const Keys = launchpad_keys.Keys;

const MidiChooseErrors = error {
    NO_MIDI_FILE_FOUND,
    NO_USER_INPUT,
    NO_INDEX_INPUT,
    INDEX_OUT_OF_BOUNDS,
};

pub fn choose_midi_file(allocator: std.mem.Allocator) ![]u8 {
    // Get midi file dir
    const midi_dir: *const [9:0]u8 = "/dev/snd/";
    var dir: fs.Dir = try fs.openDirAbsolute(midi_dir, .{ .iterate = true });
    defer dir.close();
    // Get all midi files
    var midi_entries: std.ArrayList([]u8) = std.ArrayList([]u8).init(allocator);
    defer midi_entries.deinit();
    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.mem.startsWith(u8, entry.name, "midiC")) {
            const file_path: []u8 = try fs.path.join(allocator, &[_][]const u8{"/dev/snd", entry.name});
            try midi_entries.append(file_path);
        }
    }
    // Exit if no midi file found
    if (midi_entries.items.len == 0) return error.NO_MIDI_FILE_FOUND;
    // Show the user the midi files
    for (midi_entries.items, 0..) |path, idx| {
        std.debug.print("[{}]: {s}\n", .{ idx, path });
    }
    // Prompt to choose midi file
    const stdin = std.io.getStdIn().reader();
    std.debug.print("\nEnter MIDI device to use (index): ", .{});
    var line_buf: [10]u8 = undefined;
    const user_input: ?[]u8 = try stdin.readUntilDelimiterOrEof(&line_buf, '\n');
    if (user_input == null) return error.NO_USER_INPUT;
    const choice: usize = std.fmt.parseInt(usize, user_input.?, 10) catch {
        return error.NO_INDEX_INPUT;
    };
    if (choice >= midi_entries.items.len) return error.INDEX_OUT_OF_BOUNDS;
    return midi_entries.items[choice];
}

pub fn main() !void {
    // Create allocator
    const allocator: std.mem.Allocator = std.heap.page_allocator;
    const selected_path: []u8 = try choose_midi_file(allocator);
    var file: fs.File = try fs.openFileAbsolute(selected_path, .{ .mode = fs.File.OpenMode.read_write });
    defer file.close();
    // Start logging keys
    std.debug.print("Status\tNote\tVelo\tComm\tChann\n", .{});
    var should_stop: bool = false;
    var buf: [3]u8 = undefined;
    while (!should_stop) {
        const bytes_read: usize = try file.read(buf[0..]);
        if (bytes_read != 3) {
            continue;
        }
        const status: u8 = buf[0];
        const note: u8 = buf[1];
        const velocity: u8 = buf[2];
        const command: u8 = status & 0xF0;
        const channel: u8 = status & 0x0F;
        std.debug.print("{}\t{}\t{}\t{}\t{}\n", .{ status, note, velocity, command, channel });
        
        const exit_key = Keys.getNamedKey(NamedKey.MIXER);
        if (command == exit_key.command and note == exit_key.note) {
            should_stop = true;
        }
    }
}
