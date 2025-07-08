const std = @import("std");
const fs = std.fs;

pub fn main() !void {
    const midi_path: *const[17:0]u8 = "/dev/snd/midiC1D0";
    var file: std.fs.File = try fs.openFileAbsolute(midi_path, .{ .mode = fs.File.OpenMode.read_write });
    defer file.close();
    
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
