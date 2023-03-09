const std = @import("std");
const exit = std.os.exit;
const mem = std.mem;
const Allocator = mem.Allocator;
const fs = std.fs;
const math = std.math;
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
    grid_side_len: u16,
    grid: []u1,
    back_buffer: []u1,
    window_width: f32,
    window_height: f32,
    cell_width: f32,
    cell_height: f32,

    fn init(allocator: Allocator, grid_side_len: u16) !Game {
        const grid = try allocator.alloc(u1, grid_side_len * grid_side_len);
        for (grid) |*cell| cell.* = 0;
        const back_buffer = try allocator.alloc(u1, grid_side_len * grid_side_len);
        for (back_buffer) |*cell| cell.* = 0;

        return Game{
            .grid_side_len = grid_side_len,
            .grid = grid,
            .back_buffer = back_buffer,
            .window_width = 700,
            .window_height = 700,
            .cell_width = 700 / @intToFloat(f32, grid_side_len),
            .cell_height = 700 / @intToFloat(f32, grid_side_len),
        };
    }

    fn init_from_file(game: *Game, allocator: Allocator) !void {
        const path = current_filepath orelse {
            std.log.warn("no file to load", .{});
            return;
        };

        std.log.info("loading file {s}", .{path});

        const file_size_bits = (try fs.cwd().statFile(path)).size * 8; // @Note: stat.size is in bytes!
        const grid_side_len = if (file_size_bits > math.maxInt(u16))
            math.maxInt(u8) // sqrt(math.maxInt(u16))
        else
            @intCast(u16, math.sqrt(file_size_bits));

        game.deinit(allocator);
        game.* = try Game.init(allocator, grid_side_len);

        const f = try fs.cwd().openFile(path, .{});
        defer f.close();

        var br = std.io.bitReader(.Little, f.reader());
        for (game.grid) |*cell| {
            var out: usize = undefined;
            cell.* = try br.readBits(u1, 1, &out);
        }
    }

    fn save(game: *Game, allocator: Allocator) !void {
        const exe_path = try fs.selfExeDirPathAlloc(allocator);
        defer allocator.free(exe_path);

        var exe_dir = try fs.cwd().openDir(exe_path, .{ .access_sub_paths = true });
        defer exe_dir.close();

        var save_dir = try exe_dir.makeOpenPath("saves", .{});
        defer save_dir.close();

        var buffer: ["18446744073709551615.zgol".len]u8 = undefined;
        const basename = try std.fmt.bufPrint(&buffer, "{d}.zgol", .{std.time.timestamp()});

        var save_file = try save_dir.createFile(basename, .{});
        defer save_file.close();

        const save_filename_absolute = try save_dir.realpathAlloc(allocator, basename);
        std.log.info("saving file {s}", .{save_filename_absolute});

        if (current_filepath) |path| allocator.free(path);
        current_filepath = save_filename_absolute;

        var bw = std.io.bitWriter(.Little, save_file.writer());
        for (game.grid) |cell| {
            try bw.writeBits(cell, 1);
        }

        try bw.flushBits();
    }

    fn deinit(game: *Game, allocator: Allocator) void {
        allocator.free(game.grid);
        allocator.free(game.back_buffer);
    }

    fn update_grid(game: *Game) void {
        var row: i17 = 0;
        while (row < game.grid_side_len) : (row += 1) {
            var col: i17 = 0;
            while (col < game.grid_side_len) : (col += 1) {
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
                    const check_col = @intCast(u16, @mod(col + offset[0], @as(i17, game.grid_side_len)));
                    const check_row = @intCast(u16, @mod(row + offset[1], @as(i17, game.grid_side_len)));
                    const index = check_row * game.grid_side_len + check_col;
                    alive_count += game.grid[index];
                }

                const index = @intCast(u16, row) * game.grid_side_len + @intCast(u16, col);
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

// The most recently loaded or saved file.
// Pressing 'r' will reload the game state from its contents if set.
var current_filepath: ?[]const u8 = null;

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

    defer if (current_filepath) |path| {
        allocator.free(path);
    };

    var grid_side_len: ?u16 = null;
    var load_filename: ?[]const u8 = null;
    var updates_per_second: u16 = 10;
    if (args.len > 1) {
        for (args[1..]) |arg| {
            if (mem.startsWith(u8, arg, "--load=")) {
                if (load_filename != null) {
                    std.log.err("cannot specify filename multiple times", .{});
                    exit(1);
                }
                load_filename = mem.trimLeft(u8, arg, "--load=");
            } else if (mem.startsWith(u8, arg, "--updates-per-second=")) {
                const val_str = mem.trimLeft(u8, arg, "--updates-per-second=");
                const ups = std.fmt.parseUnsigned(u16, val_str, 10) catch {
                    std.log.err("invalid updates per second: {s}", .{val_str});
                    exit(1);
                };
                if (ups < 1 or ups > 144) {
                    std.log.err("updates per second must be between 1 and 144", .{});
                    exit(1);
                }
                updates_per_second = ups;
            } else if (mem.startsWith(u8, arg, "--grid-side-len=")) {
                if (grid_side_len != null) {
                    std.log.err("cannot specify grid side length multiple times", .{});
                    exit(1);
                }
                const val_str = mem.trimLeft(u8, arg, "--grid-side-len=");
                const side_len = std.fmt.parseUnsigned(u16, val_str, 10) catch {
                    std.log.err("invalid grid side length: {s}", .{val_str});
                    exit(1);
                };
                if (side_len < 1 or side_len >= 256) {
                    std.log.err("grid side length must be between 1 and 255", .{});
                    exit(1);
                }
                grid_side_len = side_len;
            } else {
                std.log.err("unrecognized option {s}", .{arg});
                exit(1);
            }
        }
    }

    var game = try Game.init(allocator, grid_side_len orelse 10);
    if (load_filename) |path| {
        current_filepath = try fs.cwd().realpathAlloc(allocator, path);
        try game.init_from_file(allocator);
    }
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

    var mouse_left_down = false;
    var mouse_right_down = false;

    while (!quitting) {
        while (c.SDL_PollEvent(&event) != 0) {
            switch (event.type) {
                c.SDL_MOUSEBUTTONDOWN => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => mouse_left_down = true,
                    c.SDL_BUTTON_RIGHT => mouse_right_down = true,
                    else => {},
                },
                c.SDL_MOUSEBUTTONUP => switch (event.button.button) {
                    c.SDL_BUTTON_LEFT => mouse_left_down = false,
                    c.SDL_BUTTON_RIGHT => mouse_right_down = false,
                    else => {},
                },
                c.SDL_KEYDOWN => {
                    switch (event.key.keysym.sym) {
                        c.SDLK_SPACE => paused = !paused,
                        c.SDLK_EQUALS, c.SDLK_PLUS => {
                            updates_per_second = math.clamp(updates_per_second + 1, 1, 144);
                            std.log.info("updates per second = {}", .{updates_per_second});
                        },
                        c.SDLK_MINUS => {
                            updates_per_second = math.clamp(updates_per_second - 1, 1, 144);
                            std.log.info("updates per second = {}", .{updates_per_second});
                        },

                        c.SDLK_s => try game.save(allocator),
                        c.SDLK_r => try game.init_from_file(allocator),
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
            if (cell_tick_timer >= 1000 / updates_per_second) {
                cell_tick_timer = 0;
                game.update_grid();
            }
            previous_tick = now;
        } else {
            bgnd_col = .{ .r = 63, .g = 31, .b = 0 };
        }

        _ = c.SDL_SetRenderDrawColor(renderer, bgnd_col.r, bgnd_col.g, bgnd_col.b, bgnd_col.a);
        _ = c.SDL_RenderClear(renderer);

        // Draw automata state
        {
            _ = c.SDL_SetRenderDrawColor(renderer, 255, 0, 0, 255);
            var row: u32 = 0;
            while (row < game.grid_side_len) : (row += 1) {
                var col: u32 = 0;
                while (col < game.grid_side_len) : (col += 1) {
                    const alive = game.grid[row * game.grid_side_len + col] == 1;
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
            const norm_x = math.clamp(@intToFloat(f32, x) / game.window_width, 0, 1);
            const norm_y = math.clamp(@intToFloat(f32, y) / game.window_height, 0, 1);
            const grid_side_len_f = @intToFloat(f32, game.grid_side_len);
            const col = @floor(norm_x * grid_side_len_f);
            const row = @floor(norm_y * grid_side_len_f);
            const icol = math.clamp(@floatToInt(u16, col), 0, game.grid_side_len - 1);
            const irow = math.clamp(@floatToInt(u16, row), 0, game.grid_side_len - 1);

            if (mouse_left_down) {
                game.grid[irow * game.grid_side_len + icol] = 1;
            }
            if (mouse_right_down) {
                game.grid[irow * game.grid_side_len + icol] = 0;
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
