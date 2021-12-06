// analyze.zig -- given a set of computed results.txt from various pgn files using collect.zig,
// analyze which moves are seen or not, including which are disambiguations of various types.
// Also, count the number of possible moves to compare coverage percentage.
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

//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  8  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  7  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  6  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  5  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  4  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  3  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  2  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//     |       |       |       |       |       |       |       |       |
//  1  |       |       |       |       |       |       |       |       |
//     +-------+-------+-------+-------+-------+-------+-------+-------+
//         a       b       c       d       e       f       g       h

const PossibleMoves = struct {
    pawn: u64 = 0,
    knight: u64 = 0,
    queen: u64 = 0,
    king: u64 = 0,
    rook: u64 = 0,
    bishop: u64 = 0,
    extra: u64 = 0,
    total: u64 = 0,
};

fn computePossibleMoves() PossibleMoves {
    std.debug.print("Possible legal moves: (x3 to include check and checkmate)\n", .{});
    var p = PossibleMoves{};
    // How many moves can be expressed in chess notation?
    //
    // Castling
    //     O-O, O-O-O   => 2
    p.extra += 2;
    // Pawn push
    //     a2, a3, ..., a7; b2, b3, ...; ... h7   => 6x8
    //         yes you start on a2, so only a3. But black can push all the way from the other side.
    //         same with a7 for white
    p.pawn += 6 * 8;
    // Pawn promotion (white)
    //     a8=Q, a8=R, a8=B, a8=N; b8=Q...h8=Q  => 4x8
    p.pawn += 4 * 8;
    // Pawn promotion (black)
    //     a1=Q, a1=R, a1=B, a1=N; b1=Q...h1=Q  => 4x8
    p.pawn += 4 * 8;
    // Pawn captures
    //     axb2, axb3, ..., axb7; bxa; bxc; cxb; ... gxh; hxg   => 14x6
    //         ab, ba, bc,cb, cd,dc, de,ed, ef,fe, fg,gf, gh,hg  => 14
    //         2..7 => 6
    //         note that this includes en passant
    p.pawn += 14 * 6;
    // Pawn captures with promotion (white)
    //      axb8=Q, axb8=R, axb8=B, axb8=N...; bxa  => 14x4
    p.pawn += 14 * 4;
    // Pawn captures with promotion (black)
    //     axb1=Q, axb1=R, axb1=B, axb1=N...; bxa  => 14x4
    p.pawn += 14 * 4;
    // Queen, King, Rook, Knight, Bishop moves => 5x64
    //     Qa1...Qh8  => 64
    //     Ra1...Rh8  => 64
    //     Ba1...Bh8  => 64
    //     Na1...Nh8  => 64
    //     Ka1...Kh8  => 64
    p.queen += 64;
    p.rook += 64;
    p.bishop += 64;
    p.knight += 64;
    p.king += 64;
    // Takes => 5x64
    //     Qxa1...Qxh8  => 64
    //     Rxa1...Rxh8  => 64
    //     Bxa1...Bxh8  => 64
    //     Nxa1...Nxh8  => 64
    //     Kxa1...Kxh8  => 64
    p.queen += 64;
    p.rook += 64;
    p.bishop += 64;
    p.knight += 64;
    p.king += 64;
    // Disambiguations => 4x8x8x64 - 4x8
    //     Qaa1, Q1a1, ...
    //         Q,R,B
    //         a-h or 1-8 => 8 + 8
    //         a1...h8 => 64
    p.queen += (8 + 8) * 64;
    //     But! Rooks cannot disambiguate from edges from both rank AND file!
    //         Assuming that "preferring" file disambiguation is required...
    //         R1a1 is never useful. We can always say Rba1 to disambiguate from an 'a' file move.
    //              This is because 'a' file disambiguation is only needed when it could come from either direction, so a1/a8, b1/b8, ...
    //              This also means we don't have all ranks as sources for every destination.
    //                   for b2 as the destination, there's 7 source files (all but the source file), because we exclude rank 2: R1b2, R3b2, ..., R8b2
    //                   this means we have 6 source ranks, 8 destination ranks, and 7 destination files
    //         R2a3 however can be useful.
    //         rook disambiguation to cause checkmate? via discovery only....?
    //         R1b1
    //         Raa1, R1a1
    p.rook += (8) * (8 * 8) // file
    * 2; // captures too
    p.rook += (6) * (7 * 8) // rank
    * 2; // captures too
    //     But! bishops cannot disambiguate from corners!
    //         Ba1 never needs to be disambiguated. Only one row/column could legally move to corner at a time.
    //             B*a1, B*a8, B*h8, B*h1 => 4 * (8+8)
    //     Also, you could never disambiguate on the same file as the source, e.g. Bcc4 (because diagonal moves)
    //     AND, not every destination square can have all 7 files used to disambiguate.
    //        There's a relationship between which square you're on and which files are used to disambiguate.
    //        on the bottom row, a bishop can see all other files => 7 * 6
    //        on a2, you can't see the h file => 6 files
    //        on h2, you can't see the a file => 6 files
    //        on b-g2, you can see every file => 7 files
    //        on rank 3, a3 can't see h or g. b3 can't see h. c3 can see all files.
    p.bishop += ((7 * 6) // rank 1
    + (6 * 2 + 7 * 6) // rank 2
    + (5 * 2 + 6 * 2 + 7 * 4) // rank 3
    + (4 * 2 + 5 * 2 + 6 * 2 + 7 * 2) // rank 4
    + (4 * 2 + 5 * 2 + 6 * 2 + 7 * 2) // rank 5
    + (5 * 2 + 6 * 2 + 7 * 4) // rank 6
    + (6 * 2 + 7 * 6) // rank 7
    + (7 * 6)) // rank 8
    * 2; // captures as well
    //     For rank disambiguation, we have even less options, but they're symmetric for each rank
    //       you can't disambiguate ranks 1 and 8 (since you dont' have both sides)
    //       on rank 2, you can use rank 1 or 3
    //       on rank 3, you can use rank 1, 2, 4, or 5
    //       on rank 4, you can use rank 1, 2, 3, 5, 6, or 7
    //       symmetric for 5,6,7.
    p.bishop += ((8 * 2) // rank 2
    + (8 * 4) // rank 3
    + (8 * 6) // rank 4
    + (8 * 6) // rank 5
    + (8 * 4) // rank 6
    + (8 * 2)) // rank 7
    * 2; // captures as well
    // If you have 3 or more bishops, it's also possible to need to double disambiguate
    //     to require double-disambiguation, you need bishops in square around the destination
    //     this can't happen along any edge
    //     inset 1 square from the edge, you can have bishops one square diagonally offset, requiring double disambiguation. There are 4 squares there.
    p.bishop += ((4 * 20) // inset one square
    + (8 * 12) // inset two squares
    + (12 * 4) // inset three squares (center)
    ) * 2; // captures as well
    // However, any double-disambiguated bishop move cannot be check or checkmate,
    // because they NEVER control any additional squares (always <=). Thus you would have already been in check.
    // so these are excluded from our x3.

    // Disambiguation captures => 4x8x8x64 - 4x8
    //     Qaxa1, Q1xa1,
    //         Q,R,B => 4
    //         a-h => 8
    //         1-8 => 8
    //         a1...h8 => 64
    p.queen += (8 + 8) * 64;
    // Multi-Queen Disambiguation =>
    //     Qa1h8
    //     from any square, a queen can reach 7 + 7 squares
    //      every square: (7+7) * 64
    //     num possible diagonal moves increases toward the middle of the board
    //      28*7, 20*9, 12*11, 4*13
    p.queen += ((7 + 7) * 64 // same rank or file
    + 28 * 7 + 20 * 9 + 12 * 11 + 4 * 13) // diagonal moves
    * 2; // and captures

    // knight Disambiguations
    //     knights can only disambiguate from 1 or 2 rows/colums away
    //         Nbc4
    //         Nab*, Nac*
    //         ab,ac,ba,bc,bd,ca,cb,cd,ce,db,dc,de,df,ec,ed,ef,eg,fd,fe,fg,fh,ge,gf,gh,hf,hg
    //         4x8 - 2 (a) - 2 (h) - 1 (b) - 1 (g)  => 26
    p.knight += (2 + // a
        3 + // b
        4 + 4 + 4 + 4 + // c-f
        3 + // g
        2 // h
    ) * 8 // same for every file
    * 2; // captures too

    // knight rank Disambiguations
    //     N1b3
    //     BUT: you can't always disambiguate with rank. Anywhere along 1 or 8 rank, you could always use file instead.
    //     along the 2 and 7 ranks, you can only disambiguate one rank away => 2
    //     along the other ranks 3-6, you can disambiguate one or two ranks away in either direction => 4
    p.knight += ((2 + // 2
        4 + 4 + 4 + 4 + // 3-6
        2 // 7
    ) * 8) // same for every rank
    * 2; // captures too
    // knight Disambiguations captures
    //     knights can only disambiguate from 1 or 2 rows/colums away
    //         N1xa3, Nbxc4
    //         Naxb*, Naxc*
    //         ab,ac,ba,bc,bd,ca,cb,cd,ce,db,dc,de,df,ec,ed,ef,eg,fd,fe,fg,fh,ge,gf,gh,hf,hg
    //         4x8 - 2 (a) - 2 (h) - 1 (b) - 1 (g)  => 26
    // knight double disambiguations
    //     to disambiguate twice, you need 3 knights in a box attacking the same square
    //     this can either be 5x3 box or a 3x5 box
    //     the center of the box can't be on the outer edge at all
    //     inset one from the edge, you can have horizontal boxes on the top and bottom, and veritcal boxes on the side. You can't have either on the corners of the inset box.
    //        => 4 sources for c2-f2, b3-b6, g3-g6, c7-f7
    p.knight += (4 * (4 + 4 + 4 + 4) + // inset by 1, except corners, all have 1 dimension of box = 4 moves
        8 * (4 * 4)) // inset by 2 or 3 both have 2 dimensions of boxes, 3x5 and 5x3, for 4+4 possible moves
    * 2; // captures too

    var includingCheckAndMate = p;

    //
    // any move can be check  => x2
    // any move can be checkmate => x3
    // this is true for most cases, but we need to subtract the edge cases the multiply
    includingCheckAndMate.pawn *= 3;
    includingCheckAndMate.rook *= 3;
    includingCheckAndMate.bishop *= 3;
    includingCheckAndMate.knight *= 3;
    includingCheckAndMate.king *= 3;
    includingCheckAndMate.queen *= 3;

    // Multi-Queen Disambiguations from edges/diagonal to corners could never be check or checkmate
    //     Qa1h8
    includingCheckAndMate.queen -= 2 * // checks or checkmates
        2 * // non-captures or captures
        (7 + 7 + 7) * // 7*2 from both edges connecting to this corner, 7 from diagnoal
        4; // each corner

    // some double disambiguated bishop moves cannot be check/checkmate.
    // When the source piece is in the corner, it can't reveal any new squares for attacks.
    includingCheckAndMate.bishop -= (4 * 6 // 6 inner squares coming from each of all 4 edges
    ) * 2 // captures as well
    * 2; // exclude check or checkmate

    p.total = p.pawn + p.queen + p.king + p.rook + p.bishop + p.knight + p.extra;
    includingCheckAndMate.total = includingCheckAndMate.pawn + includingCheckAndMate.queen + includingCheckAndMate.king + includingCheckAndMate.rook + includingCheckAndMate.bishop + includingCheckAndMate.knight + includingCheckAndMate.extra;

    std.debug.print("Pawn:     {: >5.} ({: >6.})\n", .{ fmtComma(p.pawn), fmtComma(includingCheckAndMate.pawn) });
    std.debug.print("Rook:     {: >5.} ({: >6.})\n", .{ fmtComma(p.rook), fmtComma(includingCheckAndMate.rook) });
    std.debug.print("Knight:   {: >5.} ({: >6.})\n", .{ fmtComma(p.knight), fmtComma(includingCheckAndMate.knight) });
    std.debug.print("Bishop:   {: >5.} ({: >6.})\n", .{ fmtComma(p.bishop), fmtComma(includingCheckAndMate.bishop) });
    std.debug.print("Queen:    {: >5.} ({: >6.})\n", .{ fmtComma(p.queen), fmtComma(includingCheckAndMate.queen) });
    std.debug.print("King:     {: >5.} ({: >6.})\n", .{ fmtComma(p.king), fmtComma(includingCheckAndMate.king) });

    // We're ignoring !, !!, ?, ??, ?!, !?, these are just annotations on top of the game

    // only other person I found seriously doing this got a different answer, though they had some different assumptions:
    // https://www.chess.com/blog/kurtgodden/think-you-know-algebraic-notation

    // other fun stuff
    // most common promotion: a8=Q
    // most common checkmate: Qg7#
    // most common move: Nf3, O-O
    // most common capture: exd5

    std.debug.print("\n", .{});
    std.debug.print("There are {} possible moves without including check or checkmate\n", .{fmtComma(p.total)});
    std.debug.print("There are {} possible moves including check or checkmate\n\n", .{fmtComma(includingCheckAndMate.total)});
    return includingCheckAndMate;
}

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

    const possibleMoves = computePossibleMoves();

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
    std.debug.print("{: >15.} moves analyzed\n", .{fmtComma(totalMoves)}); // should match accumulated.numMoves, printed here to double check
    std.debug.print("\n", .{});
    std.debug.print("♟ Pawn moves:   {: >14.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(pawnInfo.total.total), percent(pawnInfo.total.total, totalMoves), fmtComma(pawnInfo.total.unique), percent(pawnInfo.total.unique, possibleMoves.pawn) });
    std.debug.print("♚ King moves:   {: >14.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(kingInfo.total.total), percent(kingInfo.total.total, totalMoves), fmtComma(kingInfo.total.unique), percent(kingInfo.total.unique, possibleMoves.king) });
    std.debug.print("♜ Rook moves:   {: >14.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(rookInfo.total.total), percent(rookInfo.total.total, totalMoves), fmtComma(rookInfo.total.unique), percent(rookInfo.total.unique, possibleMoves.rook) });
    std.debug.print("♞ Knight moves: {: >14.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(knightInfo.total.total), percent(knightInfo.total.total, totalMoves), fmtComma(knightInfo.total.unique), percent(knightInfo.total.unique, possibleMoves.knight) });
    std.debug.print("♛ Queen moves:  {: >14.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(queenInfo.total.total), percent(queenInfo.total.total, totalMoves), fmtComma(queenInfo.total.unique), percent(queenInfo.total.unique, possibleMoves.queen) });
    std.debug.print("♝ Bishop moves: {: >14.} ({d:.2}%)  -  {: >6.} unique ({d:.2}% coverage)\n", .{ fmtComma(bishopInfo.total.total), percent(bishopInfo.total.total, totalMoves), fmtComma(bishopInfo.total.unique), percent(bishopInfo.total.unique, possibleMoves.bishop) });
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
