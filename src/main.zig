const std = @import("std");

const vaxis = @import("vaxis");
const vxfw = vaxis.vxfw;

const font = @import("font.zig");

const Timer = struct {
    const MAX = (99 * std.time.s_per_hour) + (59 * std.time.s_per_min) + 59;
    duration: i64,
    remaining: i64,
    expires: i64,
    buf: [9]u8,

    // These let us remember the length of a timer without changing the width
    hours: ?u64,
    minutes: ?u64,
    seconds: u64,

    running: bool,
    started: ?i64,
    force_redraw: bool,

    pub fn init(duration_sec: i64) !Timer {
        if (duration_sec > Timer.MAX) return error.TooLarge;
        const now = std.time.milliTimestamp();
        const duration_ms = (duration_sec * std.time.ms_per_s);
        const expires = now + duration_ms;

        // zig fmt: off
        var timer = Timer{
            .duration = duration_ms,
            .remaining = duration_ms,
            .expires = expires,
            .buf = std.mem.zeroes([9]u8),

            .hours = if (duration_sec >= std.time.s_per_hour) 0 else null,
            .minutes = if (duration_sec >= std.time.s_per_min) 0 else null,
            .seconds = @intCast(duration_sec),

            .running = false,
            .started = null,
            .force_redraw = false,
        };
        // zig fmt: on

        _ = timer.update_digits();

        return timer;
    }

    pub fn start(self: *Timer) void {
        if (!self.running and !self.expired()) {
            self.started = std.time.milliTimestamp();
            self.running = true;
            self.force_redraw = true;
        }
    }

    pub fn pause(self: *Timer) void {
        self.running = false;
        self.force_redraw = true;
    }

    pub fn expired(self: *const Timer) bool {
        return self.expires <= std.time.milliTimestamp();
    }

    pub fn reset(self: *Timer) void {
        self.running = false;
        self.remaining = self.duration;
        const now = std.time.milliTimestamp();
        self.expires = now + self.duration;
        self.force_redraw = true;
    }

    pub fn update(self: *Timer) bool {
        if (!self.running) {
            if (self.force_redraw) {
                return self.update_digits();
            }
            return false;
        }

        if (self.started) |started| {
            self.expires = started + self.remaining;
            self.started = null;
        }

        const now = std.time.milliTimestamp();

        self.remaining = self.expires - now;
        if (self.remaining < 0) {
            self.remaining = 0;
            self.running = false;
        }

        return self.update_digits();
    }

    fn update_digits(self: *Timer) bool {
        self.force_redraw = false;

        var updated = false;

        var dur: u64 = @intCast(self.remaining);

        // If we're tracking hours, update the hour counter
        if (self.hours) |*h| {
            const hours = @divTrunc(dur, std.time.ms_per_hour);
            dur = @rem(dur, std.time.ms_per_hour);

            if (h.* != hours) {
                h.* = hours;
                updated = true;
            }
        }

        // If we're tracking minutes, update the minute counter
        if (self.minutes) |*m| {
            const minutes = @divTrunc(dur, std.time.ms_per_min);
            dur = @rem(dur, std.time.ms_per_min);
            if (m.* != minutes) {
                m.* = minutes;
                updated = true;
            }
        }

        const seconds = @divTrunc(dur, std.time.ms_per_s);
        if (self.seconds != seconds) {
            self.seconds = seconds;
            updated = true;
        }

        return updated;
    }

    pub fn display(self: *Timer) ![]const u8 {
        if (self.hours) |hours| {
            if (self.minutes) |minutes| {
                // zig fmt: off
                return try std.fmt.bufPrint(
                    &self.buf,
                    "{d:0>2}:{d:0>2}:{d:0>2}",
                    .{ hours, minutes, self.seconds }
                );
                // zig fmt: on
            } else {
                @panic("Having hours but no minutes is not possible");
            }
        } else if (self.minutes) |minutes| {
            // zig fmt: off
            return try std.fmt.bufPrint(
                &self.buf,
                "{d:0>2}:{d:0>2}",
                .{ minutes, self.seconds }
            );
            // zig fmt: on
        } else {
            // zig fmt: off
            return try std.fmt.bufPrint(
                &self.buf,
                "{d:0>2}",
                .{ self.seconds }
            );
            // zig fmt: on
        }
    }
};

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

    pub fn init(allocator: std.mem.Allocator, duration: i64) !App {
        return .{ .allocator = allocator, .should_quit = false, .tty = try vaxis.Tty.init(), .vx = try vaxis.init(allocator, .{}), .timer = try Timer.init(duration) };
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
        const style: vaxis.Style = .{
            .fg = .{ .index = 1 },
        };

        const win = self.vx.window();
        // Note, win.clear(), just calls `win.fill(.{.default = true})`
        // win.fill(.{ .style = style });
        win.clear();

        try self.vx.setTitle(self.tty.anyWriter(), "Pomo");
        self.vx.setMouseShape(.default);

        // Create a bordered child window
        const child = win.child(.{
            .x_off = win.width / 2 - 20,
            .y_off = win.height / 2 - 12,
            .width = 40,
            .height = 24,
            .border = .{
                .where = .all,
                .style = style,
            },
        });

        // Create the countdown clock text
        const segment: vaxis.Segment = .{
            .text = try self.timer.display(),
            .style = style,
        };
        // Center the countdown clock text
        const center = vaxis.widgets.alignment.center(child, 28, 4);
        _ = center.printSegment(segment, .{ .wrap = .grapheme });

        try self.vx.render(self.tty.anyWriter());
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    var app = try App.init(allocator, 5);
    defer app.deinit();

    try app.run();
}
