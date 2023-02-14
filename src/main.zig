const std = @import("std");
const print = std.debug.print;

const GRID_SIZE = 10;

var grid = [GRID_SIZE * GRID_SIZE]u1{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

var back_buffer = [1]u1{0} ** (GRID_SIZE * GRID_SIZE);

pub fn main() !void {
    printGrid(&grid);

    var row: i8 = 0;
    while (row < GRID_SIZE) : (row += 1) {
        var col: i8 = 0;
        while (col < GRID_SIZE) : (col += 1) {
            var alive_count: u8 = 0;

            inline for (.{
                .{ -1, -1 },
                .{ -1, 0 },
                .{ -1, 1 },
                .{ 0, -1 },
                .{ 0, 1 },
                .{ 1, -1 },
                .{ 1, 0 },
                .{ 1, 1 },
            }) |offset| {
                const check_col = @mod(row + offset[0], GRID_SIZE);
                const check_row = @mod(col + offset[1], GRID_SIZE);
                const index = @intCast(u8, check_row * GRID_SIZE + check_col);
                alive_count += grid[index];
            }

            const index = @intCast(u8, row * GRID_SIZE + col);
            if (alive_count < 2 or alive_count > 3) {
                back_buffer[index] = 0;
            } else if (alive_count == 3) {
                back_buffer[index] = 1;
            }
            printGrid(&back_buffer);
        }
    }

    // printGrid(&back_buffer);

    grid = back_buffer;
}

fn printGrid(g: []u1) void {
    for (g) |value, i| {
        if (i > 0 and i % GRID_SIZE == 0) {
            print("\n", .{});
        }
        print("{b}", .{value});
    }
    print("\n----------\n", .{});
}
