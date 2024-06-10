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

/// Create a json object map from a StringArrayHashMap(u64).
pub fn toJsonObjectMap(allocator: std.mem.Allocator, result: std.StringArrayHashMap(u64)) !std.json.Value {
    var moves = std.json.ObjectMap.init(allocator);
    var it = result.iterator();
    while (it.next()) |pair| {
        try moves.put(pair.key_ptr.*, std.json.Value{ .integer = @intCast(pair.value_ptr.*) });
    }

    return std.json.Value{ .object = moves };
}

/// Write result data as JSON to a file, or to stdout if no filename is provided.
pub fn writeResultJson(allocator: std.mem.Allocator, result: *ResultData, filename: ?[]const u8) !void {
    const resultJson = ResultJson{
        .totalGames = result.numGames,
        .totalMoves = result.numMoves,
        .moves = try toJsonObjectMap(allocator, result.*.occurrances.*),
        .interestingGames = result.interestingGames.items,
        .bytesTotal = result.bytesTotal,
        .bytesFromGames = result.bytesFromGames,
    };

    try writeJson(resultJson, filename);
}

pub fn writeSimplifiedMoves(allocator: std.mem.Allocator, result: std.StringArrayHashMap(u64), filename: ?[]const u8) !void {
    try writeJson(try toJsonObjectMap(allocator, result), filename);
}

/// Write JSON data to a file, or to stdout if no filename is provided.
pub fn writeJson(value: anytype, filename: ?[]const u8) !void {
    const writer = if (filename) |name|
        (try std.fs.cwd().createFile(name, .{ .truncate = true }))
    else
        std.io.getStdOut();

    // only cleanup the File if it's not stdout
    defer if (writer.handle == std.io.getStdOut().handle) {} else writer.close();

    try std.json.stringify(value, .{
        .whitespace = .indent_2,
    }, writer.writer());
}
