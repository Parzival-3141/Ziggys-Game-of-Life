const std = @import("std");
const print = std.debug.print;

const GRID_SIZE = 10;

var grid = [GRID_SIZE * GRID_SIZE]u1{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 1, 1, 0, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 1, 0, 0, 0,
    0, 0, 0, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

var back_buffer = [1]u1{0} ** (GRID_SIZE * GRID_SIZE);

pub fn main() !void {
    for (grid) |_, i| {
        var count: u8 = 0;

        for ([_]{
            i - GRID_SIZE - 1, i - GRID_SIZE,     i - GRID_SIZE + 1,
            i - 1,             i + 1,             i + GRID_SIZE - 1,
            i + GRID_SIZE,     i + GRID_SIZE + 1,
        }) |offset| {
            count += grid[i + offset];
        }

        if (count < 2 or count > 3) {
            back_buffer[i] = 0;
        } else if (count == 3) {
            back_buffer[i] = 1;
        }
    }

    for (back_buffer) |value, i| {
        if (i > 0 and i % GRID_SIZE == 0) {
            print("\n", .{});
        }

        print("{b}", .{value});
    }

    grid = back_buffer;
}
