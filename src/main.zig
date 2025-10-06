const std = @import("std");
const wave = @import("wave");

const print = std.debug.print;

pub fn main() !void {
    const window = try wave.window.Window.new();
    defer window.deinit();
    window.run();
}
