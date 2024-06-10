const std = @import("std");

pub const Disambiguation = struct {
    piece: u8,
    from: []const u8,
    to: []const u8,
    isFile: bool,
    isRank: bool,
    isRankFile: bool,
    isCapture: bool,
};

pub fn isDisambiguation(move: []const u8) ?Disambiguation {
    // strip leading piece, 'x' for takes, trailing promotion/check/mate/capture
    // ab1
    // 1b1
    // axb1
    // 1xb1
    // a1xb1
    const piece = move[0];
    if (std.mem.indexOfScalar(u8, "QNBR", piece) == null) {
        return null;
    }
    const middle = std.mem.trim(u8, move, "=QKNRB+#");
    const to = middle[middle.len - 2 ..];
    var from = middle[0 .. middle.len - to.len];
    var isCapture = false;
    if (from.len > 0 and from[from.len - 1] == 'x') {
        isCapture = true;
        from.len -= 1;
    }
    if (from.len == 0) {
        return null;
    }

    var isRankFile = false;
    var isRank = false;
    var isFile = false;
    if (from.len == 2) {
        isRankFile = true;
    } else if (from[0] >= '0' and from[0] <= '9') {
        isRank = true;
    } else {
        isFile = true;
    }

    return Disambiguation{
        .piece = piece,
        .from = from,
        .to = to,
        .isFile = isFile,
        .isRank = isRank,
        .isRankFile = isRankFile,
        .isCapture = isCapture,
    };
}

test "disambiguation" {
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 81, .from = { 97 }, .to = { 98, 49 }, .isFile = true, .isRank = false, .isRankFile = false, .isCapture = false }", "{?}", .{isDisambiguation("Qab1")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 81, .from = { 97, 50 }, .to = { 98, 49 }, .isFile = false, .isRank = false, .isRankFile = true, .isCapture = false }", "{?}", .{isDisambiguation("Qa2b1")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 81, .from = { 97 }, .to = { 98, 49 }, .isFile = true, .isRank = false, .isRankFile = false, .isCapture = false }", "{?}", .{isDisambiguation("Qab1")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 81, .from = { 97 }, .to = { 98, 49 }, .isFile = true, .isRank = false, .isRankFile = false, .isCapture = true }", "{?}", .{isDisambiguation("Qaxb1")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 81, .from = { 97, 49 }, .to = { 98, 49 }, .isFile = false, .isRank = false, .isRankFile = true, .isCapture = true }", "{?}", .{isDisambiguation("Qa1xb1")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 66, .from = { 97, 49 }, .to = { 98, 49 }, .isFile = false, .isRank = false, .isRankFile = true, .isCapture = true }", "{?}", .{isDisambiguation("Ba1xb1+")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 78, .from = { 49 }, .to = { 98, 49 }, .isFile = false, .isRank = true, .isRankFile = false, .isCapture = false }", "{?}", .{isDisambiguation("N1b1")});
    try std.testing.expectFmt("analyze.Disambiguation{ .piece = 78, .from = { 49 }, .to = { 98, 49 }, .isFile = false, .isRank = true, .isRankFile = false, .isCapture = false }", "{?}", .{isDisambiguation("N1b1#")});
    try std.testing.expect(isDisambiguation("b1") == null);
    try std.testing.expect(isDisambiguation("axb1") == null);
    try std.testing.expect(isDisambiguation("Qb1") == null);
}
