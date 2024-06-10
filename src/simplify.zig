const std = @import("std");

fn trimSuffix(move: []const u8) []const u8 {
    if (move.len == 0) {
        return move;
    }
    if (move[move.len - 1] == '#' or move[move.len - 1] == '+') {
        return move[0 .. move.len - 1];
    }
    return move;
}

/// "Simplify" a move notation by removing disambiguations or check/checkmate symbols.
pub fn simplifyMove(allocator: std.mem.Allocator, move: []const u8) ![]const u8 {
    if (move.len == 0) {
        return move;
    }
    if (move[0] == 'O') {
        return trimSuffix(move);
    }
    if (std.mem.indexOfScalar(u8, "QNBR", move[0]) == null) {
        // it's a pawn or king move, which don't need simplification because they are not disambiguated.
        return trimSuffix(move);
    } else {
        // it's a normal piece move
        const withoutCheck = trimSuffix(move);
        const piece = withoutCheck[0];
        const takes = if (std.mem.indexOfScalar(u8, withoutCheck, 'x') == null) "" else "x";
        const dest = withoutCheck[withoutCheck.len - 2 ..];
        return std.fmt.allocPrint(allocator, "{c}{s}{s}", .{ piece, takes, dest });
    }
}

test "simplifyMove" {
    const examples = .{
        .{ "e4", "e4" },
        .{ "e4+", "e4" },
        .{ "O-O", "O-O" },
        .{ "O-O#", "O-O" },
        .{ "O-O-O+", "O-O-O" },
        .{ "e4#", "e4" },
        .{ "exd4#", "exd4" },
        .{ "e4=Q#", "e4=Q" },
        .{ "exd8=N#", "exd8=N" },
        .{ "Qa1", "Qa1" },
        .{ "Qa1+", "Qa1" },
        .{ "Qa1#", "Qa1" },
        .{ "Qxa1#", "Qxa1" },
        .{ "Qba1#", "Qa1" },
        .{ "Q1a1#", "Qa1" },
        .{ "Qb1a1#", "Qa1" },
        .{ "Qb1xa1#", "Qxa1" },
    };
    var allocator = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer allocator.deinit();
    inline for (examples) |example| {
        const actual = try simplifyMove(allocator.allocator(), example[0]);
        try std.testing.expectEqualStrings(actual, example[1]);
    }
}
