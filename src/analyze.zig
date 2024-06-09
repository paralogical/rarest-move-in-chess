// analyze.zig -- given a set of computed results.txt from various pgn files using collect.zig,
// analyze which moves are seen or not, including which are disambiguations of various types.
// See possibleMoves.ts for counting the number of possible moves for each piece.
// See possible.py for simluating the number of possible moves to verify this info.

const std = @import("std");
const util = @import("./util.zig");
const readUntilDelimiter = util.readUntilDelimiter;
const fmtComma = util.fmtComma;

const Parse = @import("./parse.zig");
const json = @import("./json.zig");
const ResultJson = json.ResultJson;
const ResultData = Parse.ResultData;
const InterestingGame = Parse.InterestingGame;

const PossibleMoves = struct {
    castles: u64 = 0,
    pawn: u64 = 0,
    knight: u64 = 0,
    queen: u64 = 0,
    king: u64 = 0,
    rook: u64 = 0,
    bishop: u64 = 0,
    total: u64 = 0,
};

const Counts = struct {
    total: u64 = 0,
    unique: u64 = 0,
    capture: u64 = 0,
    check: u64 = 0,
    mate: u64 = 0,
    captureCheck: u64 = 0,
    captureMate: u64 = 0,
};

const PieceMoveCount = struct {
    total: Counts = Counts{},
    fileDisambiguated: Counts = Counts{},
    rankDisambiguated: Counts = Counts{},
    doubleDisambiguated: Counts = Counts{},
};

fn countInner(counts: *Counts, move: []const u8, num: u64) void {
    const isCapture = std.mem.indexOf(u8, move, "x") != null;
    const isCheck = move[move.len - 1] == '+';
    const isCheckmate = move[move.len - 1] == '#';

    counts.total += num;
    counts.unique += 1;

    if (isCheck) {
        counts.check += num;
    }
    if (isCheckmate) {
        counts.mate += num;
    }
    if (isCapture) {
        counts.capture += num;
        if (isCheck) {
            counts.captureCheck += num;
        }
        if (isCheckmate) {
            counts.captureMate += num;
        }
    }
}

pub fn count(counts: *PieceMoveCount, move: []const u8, num: u64) void {
    countInner(&counts.total, move, num);

    const disambig = isDisambiguation(move);
    if (disambig) |disambigInfo| {
        if (disambigInfo.isRankFile) {
            countInner(&counts.doubleDisambiguated, move, num);
        } else if (disambigInfo.isFile) {
            countInner(&counts.fileDisambiguated, move, num);
        } else if (disambigInfo.isRank)
            countInner(&counts.rankDisambiguated, move, num);
    }
}

pub fn printCounts(counts: *PieceMoveCount, name: []const u8, icon: []const u8, total: u64) void {
    std.debug.print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ {s} {s} {s} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n", .{ icon, name, icon });
    printCountsInner(&counts.total, name, total, "total");
    printCountsInner(&counts.fileDisambiguated, name, total, "file disambiguations");
    printCountsInner(&counts.rankDisambiguated, name, total, "rank disambiguations");
    printCountsInner(&counts.doubleDisambiguated, name, total, "double disambiguations");
}
fn printCountsInner(counts: *Counts, name: []const u8, total: u64, kind: []const u8) void {
    if (counts.total == 0) {
        // don't bother, some pieces will have 0s here like rooks can't double disambiguate and pawn/king can't disambiguate at all
        return;
    }
    std.debug.print("{: >15.} {s} {s} ({d:.9}%) \n", .{ fmtComma(counts.total), name, kind, percent(counts.total, total) });
    std.debug.print("{: >15.} {s} {s} captures ({d:.9}%) \n", .{ fmtComma(counts.capture), name, kind, percent(counts.capture, total) });
    std.debug.print("{: >15.} {s} {s} checks ({d:.9}%) \n", .{ fmtComma(counts.check), name, kind, percent(counts.check, total) });
    std.debug.print("{: >15.} {s} {s} mates ({d:.9}%) \n", .{ fmtComma(counts.mate), name, kind, percent(counts.mate, total) });
    std.debug.print("{: >15.} {s} {s} capture checks ({d:.9}%) \n", .{ fmtComma(counts.captureCheck), name, kind, percent(counts.captureCheck, total) });
    std.debug.print("{: >15.} {s} {s} capture mates ({d:.9}%) \n", .{ fmtComma(counts.captureMate), name, kind, percent(counts.captureMate, total) });
    std.debug.print("\n", .{});
}

pub fn analyze(continingDir: []const u8) !void {
    var anyPieceInfo = PieceMoveCount{};
    var queenInfo = PieceMoveCount{};
    var kingInfo = PieceMoveCount{};
    var knightInfo = PieceMoveCount{};
    var rookInfo = PieceMoveCount{};
    var bishopInfo = PieceMoveCount{};
    var pawnInfo = PieceMoveCount{};

    var potentialEnPassantMates: u64 = 0;
    var shortCastleMates: u64 = 0;
    var longCastleMates: u64 = 0;

    var pawnPromotes: u64 = 0;
    var pawnPromotesToQueen: u64 = 0;
    var pawnPromotesToKnight: u64 = 0;
    var pawnPromotesToRook: u64 = 0;
    var pawnPromotesToBishop: u64 = 0;

    var promotionInfo = PieceMoveCount{};
    var promotionQueenInfo = PieceMoveCount{};
    var promotionKnightInfo = PieceMoveCount{};
    var promotionBishopInfo = PieceMoveCount{};
    var promotionRookInfo = PieceMoveCount{};

    const allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(allocator);

    var moves = std.StringArrayHashMap(u64).init(allocator);
    var interestingGames = std.ArrayList(InterestingGame).init(allocator);
    var accumulated = ResultData{
        .occurrances = &moves,
        .interestingGames = &interestingGames,
        .allocator = allocator,
        .arena = &arena,
        .arenaAllocator = arena.allocator(),
    };

    // ----------- Read each file and add data to accumulated result -----------
    var movesAdded: u64 = 0;

    // find all results json files in the partialResults dir, combine back into one
    const dir = try std.fs.cwd().openDir(continingDir, .{});
    var diriter = dir.iterate();
    while ((try diriter.next())) |fileDef| {
        if (fileDef.kind == .file) {
            if (std.mem.startsWith(u8, fileDef.name, ".")) {
                continue;
            }
            std.debug.print("Reading data from {s}\n", .{fileDef.name});
            const file = try dir.openFile(fileDef.name, .{});

            const contents = try file.readToEndAlloc(allocator, 1024 * 1024 * 1024);
            defer allocator.free(contents);
            const parsedData = std.json.parseFromSlice(ResultJson, allocator, contents, .{}) catch {
                std.debug.print("Failed to parse JSON!\n", .{});
                continue;
            };
            defer parsedData.deinit();
            const data = parsedData.value;

            std.debug.print("  > Games: {: >14.}  Moves: {: >14.}      Bytes: {d:.1}, BytesFromGames: {d:.1}      unique moves: {}, interesting games: {}\n", .{
                fmtComma(data.totalGames),
                fmtComma(data.totalMoves),
                std.fmt.fmtIntSizeDec(data.bytesTotal),
                std.fmt.fmtIntSizeDec(data.bytesFromGames),
                fmtComma(data.moves.object.count()),
                fmtComma(data.interestingGames.len),
            });

            accumulated.numGames += data.totalGames;
            accumulated.numMoves += data.totalMoves;
            accumulated.bytesTotal += data.bytesTotal;
            accumulated.bytesFromGames += data.bytesFromGames;

            const foundMoves = data.moves.object;
            var it = foundMoves.iterator();
            while (it.next()) |entry| {
                const val: u64 = @intCast(entry.value_ptr.*.integer);
                movesAdded += val;
                const existing = moves.getPtr(entry.key_ptr.*);
                if (existing) |existingVal| {
                    existingVal.* += val;
                } else {
                    try moves.put(try allocator.dupe(u8, entry.key_ptr.*), val);
                }
            }
        }
    }
    std.debug.print("\n", .{});

    // ----------- Write out combined results.json -----------

    {
        util.sortMovesByFrequency(&moves);

        const collectedResultsName = "results.json";
        try json.writeResultJson(allocator, &accumulated, collectedResultsName);
        std.debug.print("wrote combined result data to {s}\n", .{collectedResultsName});
    }

    // ----------- Start analyzing results -----------

    std.debug.print("\n", .{});
    std.debug.print("Total Moves:  {: >18.}\n", .{fmtComma(accumulated.numMoves)});
    std.debug.print("Unique Moves: {: >18.}\n", .{fmtComma(moves.count())});
    std.debug.print("Total Games:  {: >18.}\n", .{fmtComma(accumulated.numGames)});
    std.debug.print("Data processed (uncompressed): {d:.1}\n", .{std.fmt.fmtIntSizeDec(accumulated.bytesTotal)});
    // we don't have the compressed size in this script since we pipeline the decompression, but it's about 1.5TB compressed for all of lichess.
    std.debug.print("Data processed (uncompressed, excluding annotations): {d:.1}\n", .{std.fmt.fmtIntSizeDec(accumulated.bytesFromGames)});
    std.debug.print("\n", .{});

    // This is computed from possibleMoves.ts
    const possibleJsonContent = @embedFile("./possible.json");
    const parsedPossibleMoves = std.json.parseFromSlice(PossibleMoves, allocator, possibleJsonContent, .{}) catch @panic("Failed to parse possible moves json");
    defer parsedPossibleMoves.deinit();
    const possibleMoves = parsedPossibleMoves.value;

    var it = moves.iterator();
    while (it.next()) |pair| {
        const move = pair.key_ptr.*;
        const num = pair.value_ptr.*;

        const isCapture = std.mem.indexOf(u8, move, "x") != null;
        const isCheckmate = move[move.len - 1] == '#';

        if (move[0] == 'Q') {
            count(&queenInfo, move, num);
        } else if (move[0] == 'K') {
            count(&kingInfo, move, num);
        } else if (move[0] == 'R') {
            count(&rookInfo, move, num);
        } else if (move[0] == 'N') {
            count(&knightInfo, move, num);
        } else if (move[0] == 'B') {
            count(&bishopInfo, move, num);
        } else if (move[0] == 'O') {
            // castles
            if (std.mem.eql(u8, move, "O-O#")) {
                shortCastleMates += num;
            } else if (std.mem.eql(u8, move, "O-O-O#")) {
                longCastleMates += num;
            }
        } else {
            // pawn move
            count(&pawnInfo, move, num);
            if (isCheckmate) {
                if (isCapture) {
                    const xindex = std.mem.indexOfScalar(u8, move, 'x');
                    if (xindex) |idx| {
                        const rank = move[idx + 2];
                        if (rank == '6' or rank == '3') {
                            potentialEnPassantMates += num;
                        }
                    }
                }
            }
        }

        count(&anyPieceInfo, move, num);

        if (std.mem.indexOf(u8, move, "=") != null) {
            pawnPromotes += num;
            count(&promotionInfo, move, num);
            if (std.mem.indexOf(u8, move, "=Q") != null) {
                pawnPromotesToQueen += num;
                count(&promotionQueenInfo, move, num);
            }
            if (std.mem.indexOf(u8, move, "=N") != null) {
                pawnPromotesToKnight += num;
                count(&promotionKnightInfo, move, num);
            }
            if (std.mem.indexOf(u8, move, "=R") != null) {
                pawnPromotesToRook += num;
                count(&promotionRookInfo, move, num);
            }
            if (std.mem.indexOf(u8, move, "=B") != null) {
                pawnPromotesToBishop += num;
                count(&promotionBishopInfo, move, num);
            }
        }
    }

    const totalMoves = anyPieceInfo.total.total;

    std.debug.print("\n", .{});
    std.debug.print("Total moves:    {: >15.}           -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(totalMoves), fmtComma(moves.count()), percent(moves.count(), possibleMoves.total) });
    std.debug.print("\n", .{});
    std.debug.print("♟ Pawn moves:   {: >15.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(pawnInfo.total.total), percent(pawnInfo.total.total, totalMoves), fmtComma(pawnInfo.total.unique), percent(pawnInfo.total.unique, possibleMoves.pawn) });
    std.debug.print("♚ King moves:   {: >15.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(kingInfo.total.total), percent(kingInfo.total.total, totalMoves), fmtComma(kingInfo.total.unique), percent(kingInfo.total.unique, possibleMoves.king) });
    std.debug.print("♜ Rook moves:   {: >15.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(rookInfo.total.total), percent(rookInfo.total.total, totalMoves), fmtComma(rookInfo.total.unique), percent(rookInfo.total.unique, possibleMoves.rook) });
    std.debug.print("♞ Knight moves: {: >15.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(knightInfo.total.total), percent(knightInfo.total.total, totalMoves), fmtComma(knightInfo.total.unique), percent(knightInfo.total.unique, possibleMoves.knight) });
    std.debug.print("♛ Queen moves:  {: >15.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(queenInfo.total.total), percent(queenInfo.total.total, totalMoves), fmtComma(queenInfo.total.unique), percent(queenInfo.total.unique, possibleMoves.queen) });
    std.debug.print("♝ Bishop moves: {: >15.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(bishopInfo.total.total), percent(bishopInfo.total.total, totalMoves), fmtComma(bishopInfo.total.unique), percent(bishopInfo.total.unique, possibleMoves.bishop) });
    std.debug.print("\n", .{});

    std.debug.print("{d: >14.2}% of all moves are captures\n", .{percent(anyPieceInfo.total.capture, totalMoves)});
    std.debug.print("{d: >14.2}% of all moves are checks\n", .{percent(anyPieceInfo.total.check, totalMoves)});
    std.debug.print("{d: >14.2}% of all moves are checkmates\n", .{percent(anyPieceInfo.total.mate, totalMoves)});
    std.debug.print("{d: >14.2}% of all moves are capture checks\n", .{percent(anyPieceInfo.total.captureCheck, totalMoves)});
    std.debug.print("{d: >14.2}% of all moves are capture checkmates\n", .{percent(anyPieceInfo.total.captureMate, totalMoves)});
    std.debug.print("\n", .{});

    std.debug.print("{: >15.} promotions ({d:.2}% of moves) \n", .{ fmtComma(pawnPromotes), percent(pawnPromotes, totalMoves) });
    std.debug.print("{: >15.} ♛ Queen promotions  ({d:.2}% of promotions) \n", .{ fmtComma(pawnPromotesToQueen), percent(pawnPromotesToQueen, pawnPromotes) });
    std.debug.print("{: >15.} ♜ Rook promotions   ({d:.2}% of promotions) \n", .{ fmtComma(pawnPromotesToRook), percent(pawnPromotesToRook, pawnPromotes) });
    std.debug.print("{: >15.} ♞ Knight promotions ({d:.2}% of promotions) \n", .{ fmtComma(pawnPromotesToKnight), percent(pawnPromotesToKnight, pawnPromotes) });
    std.debug.print("{: >15.} ♝ Bishop promotions ({d:.2}% of promotions) \n", .{ fmtComma(pawnPromotesToBishop), percent(pawnPromotesToBishop, pawnPromotes) });
    std.debug.print("\n", .{});

    std.debug.print("{: >15.} O-O    moves\n", .{fmtComma(moves.get("O-O").?)});
    std.debug.print("{: >15.} O-O-O  moves\n", .{fmtComma(moves.get("O-O-O").?)});
    std.debug.print("{: >15.} O-O+   moves\n", .{fmtComma(moves.get("O-O+").?)});
    std.debug.print("{: >15.} O-O-O+ moves\n", .{fmtComma(moves.get("O-O-O+").?)});
    std.debug.print("{: >15.} O-O#   moves\n", .{fmtComma(moves.get("O-O#").?)});
    std.debug.print("{: >15.} O-O-O# moves\n", .{fmtComma(moves.get("O-O-O#").?)});
    std.debug.print("\n", .{});

    const pawnMatePct = percent(pawnInfo.total.mate, totalMoves);
    const potentialEnPassantMatesPct = percent(potentialEnPassantMates, totalMoves);
    const shortCastleMatePct = percent(shortCastleMates, totalMoves);
    const longCastleMatePct = percent(longCastleMates, totalMoves);

    const totalMates = queenInfo.total.mate + rookInfo.total.mate + pawnInfo.total.mate + bishopInfo.total.mate + knightInfo.total.mate + kingInfo.total.mate;

    std.debug.print("{: >15.} ♟ Pawn mates ({d:.7}%) \n", .{ fmtComma(pawnInfo.total.mate), pawnMatePct });
    std.debug.print("{: >15.} potential en passant pawn mates ({d:.7}%) \n", .{ fmtComma(potentialEnPassantMates), potentialEnPassantMatesPct });
    std.debug.print("{: >15.} short castle mates ({d:.7}%) \n", .{ fmtComma(shortCastleMates), shortCastleMatePct });
    std.debug.print("{: >15.} long castle mates ({d:.7}%) \n", .{ fmtComma(longCastleMates), longCastleMatePct });
    std.debug.print("\n", .{});
    std.debug.print("{: >15.} ♛ Queen mates   ({d:.5}% of all moves) ({d: >2.2}% of mates)\n", .{ fmtComma(queenInfo.total.mate), percent(queenInfo.total.mate, totalMoves), percent(queenInfo.total.mate, totalMates) });
    std.debug.print("{: >15.} ♜ Rook mates    ({d:.5}% of all moves) ({d: >2.2}% of mates)\n", .{ fmtComma(rookInfo.total.mate), percent(rookInfo.total.mate, totalMoves), percent(rookInfo.total.mate, totalMates) });
    std.debug.print("{: >15.} ♟ Pawn mates    ({d:.5}% of all moves) ({d: >2.2}% of mates)\n", .{ fmtComma(pawnInfo.total.mate), pawnMatePct, percent(pawnInfo.total.mate, totalMates) });
    std.debug.print("{: >15.} ♝ Bishop mates  ({d:.5}% of all moves) ({d: >2.2}% of mates)\n", .{ fmtComma(bishopInfo.total.mate), percent(bishopInfo.total.mate, totalMoves), percent(bishopInfo.total.mate, totalMates) });
    std.debug.print("{: >15.} ♞ Knight mates  ({d:.5}% of all moves) ({d: >2.2}% of mates)\n", .{ fmtComma(knightInfo.total.mate), percent(knightInfo.total.mate, totalMoves), percent(knightInfo.total.mate, totalMates) });
    std.debug.print("{: >15.} ♚ King mates    ({d:.5}% of all moves) ({d: >2.2}% of mates)\n", .{ fmtComma(kingInfo.total.mate), percent(kingInfo.total.mate, totalMoves), percent(kingInfo.total.mate, totalMates) });
    std.debug.print("\n", .{});

    printCounts(&queenInfo, "Queen", "♛", totalMoves);
    printCounts(&bishopInfo, "Bishop", "♝", totalMoves);
    printCounts(&knightInfo, "Knight", "♞", totalMoves);
    printCounts(&rookInfo, "Rook", "♜", totalMoves);
    printCounts(&kingInfo, "King", "♚", totalMoves);
    printCounts(&pawnInfo, "Pawn", "♟", totalMoves);

    printCounts(&promotionInfo, "Promotion", "♟ → *", totalMoves);
    printCounts(&promotionQueenInfo, "Promotion to Queen", "♟ → ♛", totalMoves);
    printCounts(&promotionBishopInfo, "Promotion to Bishop", "♟ → ♛", totalMoves);
    printCounts(&promotionKnightInfo, "Promotion to Knight", "♟ → ♛", totalMoves);
    printCounts(&promotionRookInfo, "Promotion to Rook", "♟ → ♛", totalMoves);
}

fn percent(found: u64, total: u64) f64 {
    return 100.0 * @as(f64, @floatFromInt(found)) / @as(f64, @floatFromInt(total));
}

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

const Pair = struct {
    key: []const u8,
    count: u64,
};
fn cmpPair(_: void, a: Pair, b: Pair) bool {
    return a.count > b.count;
}
