const std = @import("std");

const Parse = @import("./parse.zig");
const InterestingGame = Parse.InterestingGame;
const ResultData = Parse.ResultData;

/// {
///     "totalGames": 10000,
///     "totalMoves": 1000000,
///     "bytes": 1000000,
///     "bytesFromGames": 10000,
///     "moves": {
///        "O-O": 1000,
///        "e4": 900,
///        "e5": 900,
///     },
///     "interestingGames": [
///         {
///             "move": "Ne2xf4#",
///             "type": "Knight Double Disambiguation Mate",
///             "game": "1. e4..."
///         }
///     ]
/// }
pub const ResultJson = struct {
    totalGames: u64,
    totalMoves: u64,
    bytesTotal: u64,
    bytesFromGames: u64,
    moves: std.json.Value,
    interestingGames: []InterestingGame,
};

/// Write result data as JSON to a file, or to stdout if no filename is provided.
pub fn writeResultJson(allocator: std.mem.Allocator, result: *ResultData, filename: ?[]const u8) !void {
    if (filename == null) {
        try writeResultJsonWriter(allocator, result, std.io.getStdOut().writer());
    } else {
        // create file for outputting the moves
        const outfile = try std.fs.cwd().createFile(filename.?, .{ .truncate = true });
        defer outfile.close();
        const writer = std.fs.File.writer(outfile);
        try writeResultJsonWriter(allocator, result, writer);
    }
}

fn writeResultJsonWriter(allocator: std.mem.Allocator, result: *ResultData, writer: anytype) !void {
    // copy moves into ObjectMap as std.json.Value's so we can serialize.
    // there's probably a better way to do this, but std.json.stringify didn't like my StringArrayHashMap(U64).
    var moves = std.json.ObjectMap.init(allocator);
    var it = result.*.occurrances.iterator();
    while (it.next()) |pair| {
        try moves.put(pair.key_ptr.*, std.json.Value{ .integer = @intCast(pair.value_ptr.*) });
    }

    const resultJson = ResultJson{
        .totalGames = result.numGames,
        .totalMoves = result.numMoves,
        .moves = std.json.Value{ .object = moves },
        .interestingGames = result.interestingGames.items,
        .bytesTotal = result.bytesTotal,
        .bytesFromGames = result.bytesFromGames,
    };

    try std.json.stringify(resultJson, .{
        .whitespace = .indent_2,
    }, writer);
}
