const std = @import("std");

const String = @import("String.zig");

fn font(font_height: u32) type {
    return struct {
        const Font = @This();
        const height = font_height;

        numbers: [10][height][]const u8,
        colon: [height][]const u8,
        unknown: [height][]const u8,
        separator: []const u8,

        pub fn get_height(self: *const Font) usize {
            _ = self;
            return font_height;
        }

        pub fn get_width(self: *const Font, str: []const u8) usize {
            var width: usize = 0;
            for (str) |s| {
                switch (s) {
                    '0'...'9' => {
                        const digit = s - '0';
                        if (digit <= 10) {
                            width += self.numbers[digit][0].len - 1;
                        }
                    },
                    ':' => width += self.colon.len - 1,
                    else => width += self.unknown.len - 1,
                }

                width += (self.separator.len - 1);
            }

            width -= (self.separator.len - 1);

            return width;
        }

        pub fn get_str(self: *const Font, allocator: std.mem.Allocator, str: []const u8) !String {
            const width = self.get_width(str) + 1; // Add 1 for newlines
            const total = width * height;

            var string = try String.initCapacity(allocator, total);

            for (0..height) |i| {
                var s_index: usize = 0;
                for (str) |s| {
                    switch (s) {
                        '0'...'9' => {
                            const digit = s - '0';
                            if (digit <= 10) {
                                const ss = self.numbers[digit][i];
                                try string.append(ss);
                            }
                        },
                        ':' => try string.append(self.colon[i]),
                        else => try string.append(self.unknown[i]),
                    }

                    s_index += 1;
                    if (s_index < str.len) {
                        try string.append(self.separator);
                    }
                }

                try string.append("\n");
            }

            return string;
        }
    };
}

const Small = font(1);
const Normal = font(5);

// zig fmt: off
pub const small = Small{
    .numbers = .{
        .{"0"},
        .{"1"},
        .{"2"},
        .{"3"},
        .{"4"},
        .{"5"},
        .{"6"},
        .{"7"},
        .{"8"},
        .{"9"},
    },
    .colon = .{":"},
    .unknown = .{"?"},
    .separator = "",
};

pub const medium = Normal{
    .numbers = .{
        .{"███",
          "█ █",
          "█ █",
          "█ █",
          "███",
        },
        .{"██▏", // TODO look at why I need this 1/8 block here.
          " █ ", // Without it, the .len becomes 2???
          " █ ",
          " █ ",
          "███",
        },
        .{"███",
          "  █",
          "███",
          "█  ",
          "███",
        },
        .{"███",
          "  █",
          "███",
          "  █",
          "███",
        },
        .{"█▕█", // TODO similar to 1, this reports .len = 2 if
          "█ █", // top isn't 3 non-space chars
          "███",
          "  █",
          "  █",
        },
        .{"███",
          "█  ",
          "███",
          "  █",
          "███",
        },
        .{"███",
          "█  ",
          "███",
          "█ █",
          "███",
        },
        .{"███",
          "  █",
          "  █",
          "  █",
          "  █",
        },
        .{"███",
          "█ █",
          "███",
          "█ █",
          "███",
        },
        .{"███",
          "█ █",
          "███",
          "  █",
          "███",
        },
    },
    .colon = .{" ",
               "█",
               " ",
               "█",
               " ",
    },
    .unknown = .{"███",
                 "█ █",
                 " ██",
                 " █ ",
                 " █ ",

    },
    .separator = " ",
};
// zig fmt: on
