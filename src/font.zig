fn font(font_height: u32) type {
    return struct {
        const Font = @This();
        const height = font_height;

        numbers: [10][height][]const u8,
        semicolon: [height][]const u8,
        unknown: [height][]const u8,
    };
}

const Small = font(1);
const Normal = font(9);

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
    .semicolon = .{":"},
    .unknown = .{"?"},
};
