// TODO:
// Specify starting states
// Variable grid size
// Color!

// Interactive editor:
// pausable sim, cursor to edit the grid
// can save grid to disk when paused

// Saving grid to disk: just dump the bytes!
// interpret first two u16/u32's as width/height, raw grid data from there
// Zooming!

const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const GRID_SIZE = 10;

var grid = [GRID_SIZE * GRID_SIZE]u1{
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 1, 0, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 1, 0, 0, 0, 0, 0,
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

var back_buffer = [1]u1{0} ** (GRID_SIZE * GRID_SIZE);

const window_width = 800;
const window_height = window_width;
const cell_width = window_width / GRID_SIZE;
const cell_height = window_height / GRID_SIZE;
const ticks_per_second = 10;

pub fn main() !void {
    if (c.SDL_InitSubSystem(c.SDL_INIT_VIDEO) < 0) {
        print("SDL failed to init!\n", .{});
        return;
    }
    defer c.SDL_Quit();

    const window = c.SDL_CreateWindow(
        "ziggy's game of life",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        window_width,
        window_height,
        0,
    );

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);

    var event: c.SDL_Event = undefined;
    var quitting = false;
    var paused = true;

    while (!quitting) {
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_SPACE => paused = !paused,
                        else => {},
                    }
                },

                c.SDL_QUIT => {
                    quitting = true;
                },

                else => {},
            }
        }

        // printGrid(&grid);

        if (!paused) {
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
                        const check_col = @mod(col + offset[0], GRID_SIZE);
                        const check_row = @mod(row + offset[1], GRID_SIZE);
                        const index = @intCast(u8, check_row * GRID_SIZE + check_col);
                        alive_count += grid[index];
                    }

                    const index = @intCast(u8, row * GRID_SIZE + col);
                    const is_alive = grid[index] == 1;

                    if (is_alive) {
                        back_buffer[index] = if (alive_count < 2 or alive_count > 3) 0 else 1;
                    } else if (alive_count == 3) {
                        back_buffer[index] = 1;
                    } else {
                        back_buffer[index] = 0;
                    }
                }
            }
            grid = back_buffer;
        }

        // Draw automata state
        _ = c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
        _ = c.SDL_RenderClear(renderer);
        _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
        var row: u32 = 0;
        while (row < GRID_SIZE) : (row += 1) {
            var col: u32 = 0;
            while (col < GRID_SIZE) : (col += 1) {
                const alive = grid[row * GRID_SIZE + col] == 1;
                if (!alive) continue;
                const x = @intCast(c_int, col * cell_width);
                const y = @intCast(c_int, row * cell_height);
                _ = c.SDL_RenderFillRect(renderer, &[_]c.SDL_Rect{.{
                    .x = x,
                    .y = y,
                    .w = cell_width,
                    .h = cell_height,
                }});
            }
        }

        c.SDL_RenderPresent(renderer);
        c.SDL_Delay(1000.0 / ticks_per_second);
    }
}

fn printGrid(g: []const u1) void {
    var stdout_hndl = std.io.getStdOut();
    stdout_hndl.writeAll(&.{ 0o33, '[', '2', 'J' }) catch unreachable;

    print("----------\n", .{});
    for (g, 0..) |value, i| {
        if (i > 0 and i % GRID_SIZE == 0) {
            print("\n", .{});
        }
        const char: u8 = switch (value) {
            0 => ' ',
            1 => '#',
        };
        print("{c}", .{char});
    }
    print("\n----------\n", .{});
}
