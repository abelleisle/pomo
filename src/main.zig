const std = @import("std");

const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const Timer = @import("Timer.zig");
const font = @import("font.zig");

const TIMES = enum(i64) { WORK = 1500, BREAK = 300 };

// This can contain internal events as well as Vaxis events.
// Internal events can be posted into the same queue as vaxis events to allow
// for a single event loop with exhaustive switching. Booya
const Event = union(enum) { key_press: vaxis.Key, winsize: vaxis.Winsize, time };

const App = struct {
    allocator: std.mem.Allocator,
    should_quit: bool,
    tty: vaxis.Tty,
    vx: vaxis.Vaxis,
    timer: Timer,
    work: bool,

    pub fn init(allocator: std.mem.Allocator, duration: i64) !App {
        return .{ .allocator = allocator, .should_quit = false, .tty = try vaxis.Tty.init(), .vx = try vaxis.init(allocator, .{}), .timer = try Timer.init(duration), .work = true };
    }

    pub fn deinit(self: *App) void {
        self.vx.deinit(self.allocator, self.tty.anyWriter());
        self.tty.deinit();
    }

    pub fn run(self: *App) !void {
        var loop: vaxis.Loop(Event) = .{
            .tty = &self.tty,
            .vaxis = &self.vx,
        };
        try loop.init();

        try loop.start();
        defer loop.stop();

        try self.vx.enterAltScreen(self.tty.anyWriter());

        try self.vx.queryTerminal(self.tty.anyWriter(), 1 * std.time.ns_per_s);

        while (!self.should_quit) {
            if (self.timer.update()) {
                loop.postEvent(.time);
            }

            if (self.timer.expired()) {
                try self.vx.notify(self.tty.anyWriter(), "Pomo", "Work timer complete!");

                self.work = !self.work;
                const dur: i64 = if (self.work)
                    @intFromEnum(TIMES.WORK)
                else
                    @intFromEnum(TIMES.BREAK);
                self.timer = try Timer.init(dur);
                loop.postEvent(.time);
            }

            const event = loop.tryEvent();

            if (event) |e| {
                try self.update(e);
                try self.draw();
            }

            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    fn update(self: *App, event: Event) !void {
        switch (event) {
            .key_press => |key| {
                if (key.matches('c', .{ .ctrl = true }) or
                    key.matches(vaxis.Key.escape, .{}))
                {
                    self.should_quit = true;
                }

                if (key.matches(vaxis.Key.space, .{})) {
                    if (self.timer.running) {
                        self.timer.pause();
                    } else {
                        self.timer.start();
                    }
                }

                if (key.matches('r', .{})) {
                    self.timer.reset();
                }
            },
            .winsize => |ws| try self.vx.resize(self.allocator, self.tty.anyWriter(), ws),
            else => {},
        }
    }

    fn draw(self: *App) !void {
        const index: u8 = if (self.work) 1 else 2;
        const style: vaxis.Style = .{
            .fg = .{ .index = index },
        };

        const win = self.vx.window();
        // Note, win.clear(), just calls `win.fill(.{.default = true})`
        // win.fill(.{ .style = style });
        win.clear();

        try self.vx.setTitle(self.tty.anyWriter(), "Pomo");
        self.vx.setMouseShape(.default);

        const displayed = try self.timer.display();
        const wh: u16 = @intCast(font.medium.get_width(displayed));
        const fh: u16 = @intCast(font.medium.get_height());

        const child_width = wh + 4;
        const child_height = fh + 4;

        // Create a bordered child window
        const child = win.child(.{
            .x_off = win.width / 2 - (child_width / 2),
            .y_off = win.height / 2 - (child_height / 2),
            .width = child_width,
            .height = child_height,
            .border = .{
                .where = .all,
                .style = style,
            },
        });

        const whh = @max(1, wh / 2);
        // const fhh = @max(1, fh / 2);

        var str = try font.medium.get_str(self.allocator, displayed);
        defer str.deinit();

        // Create the countdown clock text
        const segment: vaxis.Segment = .{
            .text = str.str(),
            .style = style,
        };
        // Center the countdown clock text
        const center = vaxis.widgets.alignment.center(child, whh, fh);
        _ = center.printSegment(segment, .{ .wrap = .grapheme });

        try self.vx.render(self.tty.anyWriter());
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var app = try App.init(allocator, @intFromEnum(TIMES.WORK));
    defer app.deinit();

    try app.run();
}
