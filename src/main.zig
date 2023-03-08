// TODO:
// Saving grid to disk: just dump the bytes!
// interpret first two u16/u32's as width/height, raw grid data from there

// Camera zooming! (maybe...)
// possibly change window aspect ratio based on the grid aspect ratio..?

const std = @import("std");
const print = std.debug.print;

const c = @cImport({
    @cInclude("SDL2/SDL.h");
});

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8 = 255,
};

const Game = struct {
    grid_size: u16,
    grid: []u1,
    back_buffer: []u1,
    window_width: f32,
    window_height: f32,
    cell_width: f32,
    cell_height: f32,
    updates_per_second: u16,

    fn init(allocator: std.mem.Allocator, grid_size: u16) !Game {
        const grid = try allocator.alloc(u1, grid_size * grid_size);
        for (grid) |*cell| cell.* = 0;
        const back_buffer = try allocator.alloc(u1, grid_size * grid_size);
        for (back_buffer) |*cell| cell.* = 0;

        return Game{
            .grid_size = grid_size,
            .grid = grid,
            .back_buffer = back_buffer,
            .window_width = 700,
            .window_height = 700,
            .cell_width = 700 / @intToFloat(f32, grid_size),
            .cell_height = 700 / @intToFloat(f32, grid_size),
            .updates_per_second = 10,
        };
    }

    fn deinit(game: *Game, allocator: std.mem.Allocator) void {
        allocator.free(game.grid);
        allocator.free(game.back_buffer);
    }

    fn updateGrid(game: *Game) void {
        var row: i17 = 0;
        while (row < game.grid_size) : (row += 1) {
            var col: i17 = 0;
            while (col < game.grid_size) : (col += 1) {
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
                    const check_col = @intCast(u16, @mod(col + offset[0], @as(i17, game.grid_size)));
                    const check_row = @intCast(u16, @mod(row + offset[1], @as(i17, game.grid_size)));
                    const index = check_row * game.grid_size + check_col;
                    alive_count += game.grid[index];
                }

                const index = @intCast(u16, row) * game.grid_size + @intCast(u16, col);
                const is_alive = game.grid[index] == 1;

                if (is_alive) {
                    game.back_buffer[index] = if (alive_count < 2 or alive_count > 3) 0 else 1;
                } else if (alive_count == 3) {
                    game.back_buffer[index] = 1;
                } else {
                    game.back_buffer[index] = 0;
                }
            }
        }
        var old_grid = game.grid;
        game.grid = game.back_buffer;
        game.back_buffer = old_grid;
    }
};

pub fn main() !void {
    if (c.SDL_InitSubSystem(c.SDL_INIT_VIDEO) < 0) {
        print("SDL failed to init!\n", .{});
        return;
    }
    defer c.SDL_Quit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var grid_size: u16 = 10;
    if (args.len > 1) {
        for (args[1..]) |arg| {
            if (std.mem.startsWith(u8, arg, "--grid-size=")) {
                const val_str = std.mem.trimLeft(u8, arg, "--grid-size=");
                const size = std.fmt.parseUnsigned(u16, val_str, 10) catch {
                    std.log.err("invalid grid size: {s}", .{val_str});
                    std.os.exit(1);
                };
                if (size < 1 or size >= 256) {
                    std.log.err("grid size must be between 1 and 255", .{});
                    std.os.exit(1);
                }
                grid_size = size;
            } else {
                std.log.err("unrecognized option {s}", .{arg});
                std.os.exit(1);
            }
        }
    }

    var game = try Game.init(allocator, grid_size);
    defer game.deinit(allocator);

    const window = c.SDL_CreateWindow(
        "ziggy's game of life",
        c.SDL_WINDOWPOS_CENTERED,
        c.SDL_WINDOWPOS_CENTERED,
        @floatToInt(c_int, game.window_width),
        @floatToInt(c_int, game.window_height),
        0,
    );

    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED);

    var event: c.SDL_Event = undefined;
    var quitting = false;
    var paused = true;
    var cell_tick_timer: u32 = 0;
    var previous_tick = c.SDL_GetTicks();

    while (!quitting) {
        var clicked = false;

        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_MOUSEBUTTONDOWN => {
                    if (event.button.button == c.SDL_BUTTON_LEFT) clicked = true;
                },
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_SPACE => paused = !paused,
                        c.SDLK_EQUALS, c.SDLK_PLUS => {
                            game.updates_per_second = std.math.clamp(game.updates_per_second + 1, 1, 144);
                            std.log.info("game.updates_per_second = {}", .{game.updates_per_second});
                        },
                        c.SDLK_MINUS => {
                            game.updates_per_second = std.math.clamp(game.updates_per_second - 1, 1, 144);
                            std.log.info("game.updates_per_second = {}", .{game.updates_per_second});
                        },
                        else => {},
                    }
                },
                c.SDL_QUIT => quitting = true,
                else => {},
            }
        }

        var bgnd_col = Color{ .r = 0, .g = 0, .b = 0 };

        if (!paused) {
            const now = c.SDL_GetTicks();
            const dt = now - previous_tick;
            cell_tick_timer += dt;
            if (cell_tick_timer >= 1000 / game.updates_per_second) {
                cell_tick_timer = 0;
                game.updateGrid();
            }
            previous_tick = now;
        } else {
            // _ = c.SDL_SetRenderDrawColor(renderer, 255, 127, 0, 255);
            // _ = c.SDL_RenderDrawRect(renderer, &[_]c.SDL_Rect{.{
            //     .x = 0,
            //     .y = 0,
            //     .w = window_width,
            //     .h = wind,
            // }});
            bgnd_col = .{ .r = 63, .g = 31, .b = 0 };
        }

        _ = c.SDL_SetRenderDrawColor(renderer, bgnd_col.r, bgnd_col.g, bgnd_col.b, bgnd_col.a);
        _ = c.SDL_RenderClear(renderer);

        // Draw automata state
        {
            _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
            var row: u32 = 0;
            while (row < game.grid_size) : (row += 1) {
                var col: u32 = 0;
                while (col < game.grid_size) : (col += 1) {
                    const alive = game.grid[row * game.grid_size + col] == 1;
                    if (!alive) continue;

                    _ = c.SDL_RenderFillRectF(renderer, &[_]c.SDL_FRect{.{
                        .x = @intToFloat(f32, col) * game.cell_width,
                        .y = @intToFloat(f32, row) * game.cell_height,
                        .w = game.cell_width,
                        .h = game.cell_height,
                    }});
                }
            }
        }

        // Draw selection
        {
            var x: c_int = undefined;
            var y: c_int = undefined;
            _ = c.SDL_GetMouseState(&x, &y);
            const norm_x = @intToFloat(f32, x) / game.window_width;
            const norm_y = @intToFloat(f32, y) / game.window_height;
            const col = @floor(norm_x * @intToFloat(f32, game.grid_size));
            const row = @floor(norm_y * @intToFloat(f32, game.grid_size));

            if (clicked) {
                const icol = @floatToInt(u16, col);
                const irow = @floatToInt(u16, row);
                game.grid[irow * game.grid_size + icol] = ~game.grid[irow * game.grid_size + icol];
            }

            _ = c.SDL_SetRenderDrawColor(renderer, 0, 255, 0, 255);
            _ = c.SDL_RenderDrawRectF(renderer, &[_]c.SDL_FRect{.{
                .x = col * game.cell_width,
                .y = row * game.cell_height,
                .w = game.cell_width,
                .h = game.cell_height,
            }});
        }

        c.SDL_RenderPresent(renderer);
    }
}
