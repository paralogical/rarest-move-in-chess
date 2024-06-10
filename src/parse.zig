const std = @import("std");
const Allocator = std.mem.Allocator;

const isDisambiguation = @import("./disambiguation.zig").isDisambiguation;

fn log(
    comptime format: []const u8,
    args: anytype,
) void {
    std.debug.print(format, args);
}

pub const InterestingGame = struct {
    type: RareMoveType,
    game: []const u8,
    move: []const u8,
};

pub const ResultData = struct {
    occurrances: *std.StringArrayHashMap(u64),
    interestingGames: *std.ArrayList(InterestingGame),
    allocator: Allocator,
    arena: *std.heap.ArenaAllocator,
    arenaAllocator: Allocator,
    numGames: u64 = 0,
    numMoves: u64 = 0,
    bytesTotal: u64 = 0,
    bytesFromGames: u64 = 0,

    pub fn deinit(self: *ResultData) void {
        self.occurrances.deinit();

        for (self.interestingGames.items) |item| {
            self.allocator.free(item.game);
        }
        self.interestingGames.deinit();
        self.arena.deinit();
    }
};

/// Record a move. If it's not yet been seen, we need to dupe so we own the memory
fn record(resultData: *ResultData, keyUnowned: []const u8) !void {
    if (!resultData.occurrances.*.contains(keyUnowned)) {
        const key: []const u8 = try resultData.arenaAllocator.dupe(u8, keyUnowned);
        try resultData.occurrances.*.put(key, 1);
    } else {
        const count = resultData.occurrances.get(keyUnowned) orelse 0;
        try resultData.occurrances.*.put(keyUnowned, count + 1);
    }
    resultData.numMoves += 1;
}

pub fn extractMoves(game: []u8, resultData: *ResultData) !void {
    resultData.numGames += 1;
    var parser = Parser.init(game);
    while (true) {
        const token = parser.getToken();
        switch (token) {
            Token.EOF => break,
            Token.annotation => continue,
            Token.moveNum => continue,
            Token.result => continue,
            Token.move => |move| {
                try record(resultData, move);
                const interestingMoveType = isInterestingMove(move);
                if (isMoveWorthPrinting(interestingMoveType)) {
                    try resultData.interestingGames.append(InterestingGame{
                        .type = interestingMoveType,
                        .game = try resultData.allocator.dupe(u8, game),
                        .move = try resultData.allocator.dupe(u8, move),
                    });
                }
            },
        }
    }
}

test "extract_moves.simple" {
    const rawdata =
        \\1. d4 d5 2. c4 e6 3. Nc3 Nf6?! 4. Nf3! Be7 5. Nc3 h6 6. Bh4 O-O 7. e3 b6 8.  cxd5 Nxd5#  0-1
    ;
    const data = try std.testing.allocator.dupe(u8, rawdata);
    defer std.testing.allocator.free(data);
    var occurrances = std.StringArrayHashMap(u64).init(std.testing.allocator);
    var interestingGames = std.ArrayList(InterestingGame).init(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    var result = ResultData{
        .occurrances = &occurrances,
        .interestingGames = &interestingGames,
        .allocator = std.testing.allocator,
        .arena = &arena,
        .arenaAllocator = arena.allocator(),
    };
    defer result.deinit();

    try extractMoves(data, &result);
    try std.testing.expectEqual(occurrances.get("d4"), 1);
    try std.testing.expectEqual(occurrances.get("d5"), 1);
    try std.testing.expectEqual(occurrances.get("c4"), 1);
    try std.testing.expectEqual(occurrances.get("e6"), 1);
    try std.testing.expectEqual(occurrances.get("Nc3"), 2);
    try std.testing.expectEqual(occurrances.get("Nf6"), 1);
    try std.testing.expectEqual(occurrances.get("Nf3"), 1);
    try std.testing.expectEqual(occurrances.get("Be7"), 1);
    try std.testing.expectEqual(occurrances.get("h6"), 1);
    try std.testing.expectEqual(occurrances.get("Bh4"), 1);
    try std.testing.expectEqual(occurrances.get("O-O"), 1);
    try std.testing.expectEqual(occurrances.get("e3"), 1);
    try std.testing.expectEqual(occurrances.get("b6"), 1);
    try std.testing.expectEqual(occurrances.get("cxd5"), 1);
    try std.testing.expectEqual(occurrances.get("Nxd5#"), 1);
}

test "extract_moves.complex" {
    const rawdata =
        \\1. e4 { [%eval 0.28] } 1... g6 { [%eval 0.64] } 2. Bc4 { [%eval 0.39] } 2... e4 { [%eval 0.39] } 3. Nf3 { [%eval 0.24] } 3... e6 { [%eval 0.33] } 4. O-O { [%eval 0.2] } 4... Ne7 { [%eval 0.24] }  5. Bc6# 1-0
    ;
    const data = try std.testing.allocator.dupe(u8, rawdata);
    defer std.testing.allocator.free(data);
    var occurrances = std.StringArrayHashMap(u64).init(std.testing.allocator);
    var interestingGames = std.ArrayList(InterestingGame).init(std.testing.allocator);
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    var result = ResultData{
        .occurrances = &occurrances,
        .interestingGames = &interestingGames,
        .allocator = std.testing.allocator,
        .arena = &arena,
        .arenaAllocator = arena.allocator(),
    };
    defer result.deinit();

    try extractMoves(data, &result);
    try std.testing.expectEqual(occurrances.get("e4"), 2);
    try std.testing.expectEqual(occurrances.get("g6"), 1);
    try std.testing.expectEqual(occurrances.get("Bc4"), 1);
    try std.testing.expectEqual(occurrances.get("Nf3"), 1);
    try std.testing.expectEqual(occurrances.get("e6"), 1);
    try std.testing.expectEqual(occurrances.get("O-O"), 1);
    try std.testing.expectEqual(occurrances.get("Ne7"), 1);
    try std.testing.expectEqual(occurrances.get("Bc6#"), 1);

    try std.testing.expectEqual(occurrances.count(), 8);
}

const Token = union(enum) {
    moveNum: void,
    move: []u8,
    annotation: void,
    result: void,
    EOF: void,
};

/// Very simple & dumb parser of pgn format.
/// Generally this format looks like:
/// [some annotation]
/// 1. e4 d5 2. exd5 Nf6
/// Note we need to skip over in-game annotations like { [%clk ...] }
const Parser = struct {
    data: []u8,

    state: State = State.start,

    const State = enum {
        start,
        afterMoveNum,
        afterMove1,
    };

    pub fn init(data: []u8) Parser {
        return Parser{ .data = data };
    }

    pub fn getToken(self: *Parser) Token {
        if (self.data.len == 0) {
            return Token.EOF;
        }
        self.consumeWhitespace();
        self.consumeAnnotation();
        switch (self.state) {
            .start => {
                // we may be after move 2, which could be game over
                if (self.tryConsumeScore()) {
                    self.state = .start;
                    return .result;
                }
                _ = self.consumeUntilNonWhitespace();
                self.state = .afterMoveNum;
                return .moveNum;
            },
            .afterMoveNum => {
                const move = self.consumeUntilNonWhitespace();
                self.state = .afterMove1;
                return Token{ .move = move };
            },
            .afterMove1 => {
                if (self.tryConsumeScore()) {
                    self.state = .start;
                    return .result;
                }
                const move = self.consumeUntilNonWhitespace();
                self.state = .start;
                return Token{ .move = move };
            },
        }
        return Token.EOF;
    }

    pub fn tryConsume(self: *Parser, s: []const u8) bool {
        if (self.data.len < s.len) {
            return false;
        }
        if (std.mem.eql(u8, self.data[0..s.len], s)) {
            self.data.ptr += s.len;
            self.data.len -= s.len;
            return true;
        }
        return false;
    }

    fn consumeUpto(self: *Parser, ch: u8) void {
        while (self.data.len > 0 and self.data[0] != ch) {
            self.data.ptr += 1;
            self.data.len -= 1;
        }
    }

    fn consumeWhitespace(self: *Parser) void {
        while (self.data.len > 0 and isWhitespace(self.data[0])) {
            self.data.ptr += 1;
            self.data.len -= 1;
        }
    }

    fn consumeAnnotation(self: *Parser) void {
        if (self.data[0] == '{') {
            self.consumeUpto('}');
            _ = self.tryConsume("}");
            self.consumeWhitespace();
            // there might be a marker to resume the move:
            // 1. e4 { [%eval 0.1] } 1... e5
            //                       ^^^^
            // it could be 1... 10... 100...
            if (self.data.len > 3) {
                const token = self.peekWhileNonWhitespace();
                if ((token.len == 4 and isNumber(token[0]) and token[1] == '.' and token[2] == '.' and token[3] == '.') or
                    (token.len == 5 and isNumber(token[0]) and isNumber(token[1]) and token[2] == '.' and token[3] == '.' and token[4] == '.') or
                    (token.len == 6 and isNumber(token[0]) and isNumber(token[1]) and isNumber(token[2]) and token[3] == '.' and token[4] == '.' and token[5] == '.'))
                {
                    _ = self.consumeUntilNonWhitespace();
                    self.consumeWhitespace();
                }
            }
        }
    }

    fn peekWhileNonWhitespace(self: *Parser) []u8 {
        var i: u32 = 0;
        while (self.data.len > i and !isWhitespace(self.data[i])) {
            i += 1;
        }
        return self.data[0..i];
    }

    fn consumeUntilNonWhitespace(self: *Parser) []u8 {
        var found = self.data[0..];
        var i: u32 = 0;
        while (self.data.len > 0 and !isWhitespace(self.data[0])) {
            self.data.ptr += 1;
            self.data.len -= 1;
            i += 1;
        }
        // some moves are annotated with ? or ! as commentary on the quality of the move, ignore this
        const q = std.mem.indexOfScalar(u8, found[0..i], '?') orelse 10000;
        const e = std.mem.indexOfScalar(u8, found[0..i], '!') orelse 10000;
        return found[0..@min(i, @min(q, e))];
    }

    pub fn tryConsumeScore(self: *Parser) bool {
        // notation can end mid-move or after a move with a score like 1-0 giving the outcome of the game
        // * means the game is ongoing, which is possible for correspondance games
        return self.tryConsume("0-1") or self.tryConsume("1-0") or self.tryConsume("1/2-1/2") or self.tryConsume("*");
    }
};

pub const RareMoveType = enum(u8) {
    none,
    queenDoubleDisambiguationCaptureMate,
    knightDoubleDisambiguationMate,
    knightDoubleDisambiguationCheck,
    knightDoubleDisambiguationCapture,
    knightDoubleDisambiguationCaptureMate,
    knightDoubleDisambiguationCaptureCheck,
    bishopFileDisambiguationCaptureMate,
    bishopRankDisambiguationCaptureMate,
    bishopDoubleDisambiguationCapture,
    bishopDoubleDisambiguationCheck,
    bishopDoubleDisambiguationMate,
    bishopDoubleDisambiguationCaptureCheck,
    bishopDoubleDisambiguationCaptureMate,
};

fn isInterestingMove(move: []const u8) RareMoveType {
    if (move.len < 6) {
        return .none;
    }
    const isMate = move[move.len - 1] == '#';
    const isCheck = move[move.len - 1] == '+';
    if (move[0] == 'B') {
        const disambig = isDisambiguation(move);
        if (disambig != null) {
            // Ba1a4# Ba1xa4 Ba1a4+
            if (disambig.?.isRankFile) {
                if (isMate) {
                    if (disambig.?.isCapture) {
                        return .bishopDoubleDisambiguationCaptureMate;
                    }
                    return .bishopDoubleDisambiguationMate;
                }
                if (isCheck) {
                    if (disambig.?.isCapture) {
                        return .bishopDoubleDisambiguationCaptureCheck;
                    }
                    return .bishopDoubleDisambiguationCheck;
                }

                if (disambig.?.isCapture) {
                    return .bishopDoubleDisambiguationCapture;
                }
            }
            // B1xa4#
            if (isMate and disambig.?.isCapture and disambig.?.isRank) {
                return .bishopRankDisambiguationCaptureMate;
            }
            // Baxa4#
            if (isMate and disambig.?.isCapture and disambig.?.isFile) {
                return .bishopFileDisambiguationCaptureMate;
            }
        }
    } else if (move[0] == 'Q') {
        const disambig = isDisambiguation(move);
        if (disambig) |d| {
            // Qa1xa4#
            if (isMate and d.isRankFile and d.isCapture) {
                return .queenDoubleDisambiguationCaptureMate;
            }
        }
    } else if (move[0] == 'N') {
        const disambig = isDisambiguation(move);
        if (disambig) |d| {
            // Na1a4#, Na1a4+, Na1xa4
            if (d.isRankFile) {
                if (isMate) {
                    if (disambig.?.isCapture) {
                        return .knightDoubleDisambiguationCaptureMate;
                    }
                    return .knightDoubleDisambiguationMate;
                }
                if (isCheck) {
                    if (disambig.?.isCapture) {
                        return .knightDoubleDisambiguationCaptureCheck;
                    }
                    return .knightDoubleDisambiguationCheck;
                }

                if (disambig.?.isCapture) {
                    return .knightDoubleDisambiguationCapture;
                }
            }
        }
    }
    return .none;
}

fn isMoveWorthPrinting(move: RareMoveType) bool {
    return switch (move) {
        .queenDoubleDisambiguationCaptureMate,
        .knightDoubleDisambiguationCaptureMate,
        .knightDoubleDisambiguationCaptureCheck,
        .bishopFileDisambiguationCaptureMate,
        .bishopRankDisambiguationCaptureMate,
        .bishopDoubleDisambiguationCapture,
        .bishopDoubleDisambiguationCheck,
        .bishopDoubleDisambiguationMate,
        .bishopDoubleDisambiguationCaptureCheck,
        .bishopDoubleDisambiguationCaptureMate,
        => true,
        .knightDoubleDisambiguationMate,
        .knightDoubleDisambiguationCheck,
        .knightDoubleDisambiguationCapture,
        .none,
        => false,
    };
}

test "isInterestingMove" {
    try std.testing.expectEqual(isInterestingMove("e4"), RareMoveType.none);
    try std.testing.expectEqual(isInterestingMove("Qa1xa4#"), RareMoveType.queenDoubleDisambiguationCaptureMate);
    try std.testing.expectEqual(isInterestingMove("Qa1xa4"), RareMoveType.none);
    try std.testing.expectEqual(isInterestingMove("Qa1a4#"), RareMoveType.none);

    try std.testing.expectEqual(isInterestingMove("Ba1xa4#"), RareMoveType.bishopDoubleDisambiguationCaptureMate);
    try std.testing.expectEqual(isInterestingMove("Ba1xa4"), RareMoveType.bishopDoubleDisambiguationCapture);
    try std.testing.expectEqual(isInterestingMove("Ba1a4#"), RareMoveType.bishopDoubleDisambiguationMate);
    try std.testing.expectEqual(isInterestingMove("Ba1a4+"), RareMoveType.bishopDoubleDisambiguationCheck);

    try std.testing.expectEqual(isInterestingMove("B1xa4#"), RareMoveType.bishopRankDisambiguationCaptureMate);
    try std.testing.expectEqual(isInterestingMove("B1xa4"), RareMoveType.none);
    try std.testing.expectEqual(isInterestingMove("B1a4#"), RareMoveType.none);

    try std.testing.expectEqual(isInterestingMove("Baxa4#"), RareMoveType.bishopFileDisambiguationCaptureMate);
    try std.testing.expectEqual(isInterestingMove("Baxa4"), RareMoveType.none);
    try std.testing.expectEqual(isInterestingMove("Baa4#"), RareMoveType.none);

    try std.testing.expectEqual(isInterestingMove("Na1xa4#"), RareMoveType.knightDoubleDisambiguationCaptureMate);
    try std.testing.expectEqual(isInterestingMove("Na1a4#"), RareMoveType.knightDoubleDisambiguationMate);
    try std.testing.expectEqual(isInterestingMove("Na1a4+"), RareMoveType.knightDoubleDisambiguationCheck);
    try std.testing.expectEqual(isInterestingMove("Na1xa4"), RareMoveType.knightDoubleDisambiguationCapture);
}

pub fn isWhitespace(ch: u8) bool {
    return ch == ' ' or ch == '\n' or ch == '\r';
}

/// Seek through a slice until we see annotations with (\[.*\]\n)+ end
/// return index into slice after annotations
pub fn seekThroughAnnotations(slice: []u8) usize {
    var i: usize = 0;
    while (true) {
        if (i == slice.len) return i;
        if (i > slice.len) return slice.len;
        if (slice[i] == ']') i += 1;
        while (i < slice.len and isWhitespace(slice[i])) : (i += 1) {}
        if (i >= slice.len or slice[i] != '[') {
            return i;
        }
        i += 1;
        while (i < slice.len and slice[i] != ']') : (i += 1) {}
        i += 1;
    }
}

test "seekThrough" {
    const rawdata =
        \\[Event "Rated Bullet game"]
        \\[Site "https://lichess.org/ftp0zlqh"]
        \\[White "Thiago"]
        \\[Black "tkngrafik"]
        \\[Result "1-0"]
        \\[UTCDate "2013.05.04"]
        \\[UTCTime "16:20:13"]
        \\[WhiteElo "1716"]
        \\[BlackElo "1714"]
        \\[WhiteRatingDiff "+11"]
        \\[BlackRatingDiff "-11"]
        \\[ECO "C25"]
        \\[Opening "Vienna Game: Max Lange Defense"]
        \\[TimeControl "120+1"]
        \\[Termination "Time forfeit"]
        \\
        \\1. e4 e5 2. Nc3 Nc6 3. b3 Nge7 4. Nge2 g6 5. Bb2 Bg7 6. g3 O-O 7. Bg2 d6 8. O-O Be6 9. f4 f5 10. exf5 gxf5 11. fxe5 Bxe5 12. d4 Bf6 13. d5 Nxd5 14. Nxd5 Bxb2 15. Rb1 Bg7 16. Nef4 Qd7 17. Re1 Rae8 18. Qh5 Bf7 19. Qg5 h6 20. Nf6+ Kh8 21. Nxd7 Rxe1+ 22. Rxe1 hxg5 23. Nxf8 gxf4 24. Nd7 fxg3 25. hxg3 Bd4+ 26. Kh1 Kg7 27. Bxc6 bxc6 28. Nb8 c5 29. Nc6 Bf6 30. Nxa7 Kf8 31. Nb5 Be5 32. Kg2 Bd5+ 33. Kh2 c6 34. Na7 Ke7 35. c4 Be4 36. a3 Kd7 37. b4 cxb4 38. axb4 Kc7 39. Re2 Bd3 40. Ra2 Bxc4 41. b5 Bxa2 42. bxc6 Bd5 43. Nb5+ Kxc6 44. Na3 Be4 45. Kh3 1-0
        \\
    ;
    var data = try std.testing.allocator.dupe(u8, rawdata);
    defer std.testing.allocator.free(data);
    const result = seekThroughAnnotations(data);
    try std.testing.expectEqualStrings(data[result..], "1. e4 e5 2. Nc3 Nc6 3. b3 Nge7 4. Nge2 g6 5. Bb2 Bg7 6. g3 O-O 7. Bg2 d6 8. O-O Be6 9. f4 f5 10. exf5 gxf5 11. fxe5 Bxe5 12. d4 Bf6 13. d5 Nxd5 14. Nxd5 Bxb2 15. Rb1 Bg7 16. Nef4 Qd7 17. Re1 Rae8 18. Qh5 Bf7 19. Qg5 h6 20. Nf6+ Kh8 21. Nxd7 Rxe1+ 22. Rxe1 hxg5 23. Nxf8 gxf4 24. Nd7 fxg3 25. hxg3 Bd4+ 26. Kh1 Kg7 27. Bxc6 bxc6 28. Nb8 c5 29. Nc6 Bf6 30. Nxa7 Kf8 31. Nb5 Be5 32. Kg2 Bd5+ 33. Kh2 c6 34. Na7 Ke7 35. c4 Be4 36. a3 Kd7 37. b4 cxb4 38. axb4 Kc7 39. Re2 Bd3 40. Ra2 Bxc4 41. b5 Bxa2 42. bxc6 Bd5 43. Nb5+ Kxc6 44. Na3 Be4 45. Kh3 1-0\n");
    try std.testing.expectEqual(result, 353);
}

fn isNumber(a: u8) bool {
    return a >= '0' and a <= '9';
}
