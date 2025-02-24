const std = @import("std");

const Timer = @This();

const MAX = (99 * std.time.s_per_hour) + (59 * std.time.s_per_min) + 59;
duration: i64, // The duration of the timer in ms, should only be set on init
remaining: i64, // The amount of ms remaining
expires: i64, // When the timer expires, ms timestamp

running: bool, // Is the timer currently running
started: ?i64, //
force_redraw: bool,

// These let us remember the length of a timer without changing the width
hours: ?u64,
minutes: ?u64,
seconds: u64,
buf: [9]u8,

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
    if (self.remaining <= 0) {
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
