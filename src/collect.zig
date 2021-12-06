const std = @import("std");
const Allocator = std.mem.Allocator;
const util = @import("./util.zig");
const megabytes = util.megabytes;
const fmtComma = util.fmtComma;
const fmtProgress = util.fmtProgress;
const clearCurrentLine = util.clearCurrentLine;
const fmtTimeSec = util.fmtTimeSec;

const Parse = @import("./parse.zig");
const InterestingGame = Parse.InterestingGame;
const ResultData = Parse.ResultData;

const json = @import("./json.zig");
const ResultJson = json.ResultJson;

const c = @cImport({
    @cInclude("bzlib.h");
    @cInclude("stdio.h");
});

const Pair = struct {
    key: []const u8,
    count: u64,
};
fn cmpPair(_: void, a: Pair, b: Pair) bool {
    return a.count > b.count;
}

fn log(
    comptime format: []const u8,
    args: anytype,
) void {
    std.debug.print(format, args);
}

pub fn collectStdin() anyerror!void {
    const allocator: Allocator = std.heap.c_allocator;

    log("reading from stdin", .{});

    // Read from stdin
    const in = std.io.getStdIn();
    var buf = std.io.bufferedReader(in.reader());
    var r = buf.reader();

    // Keep everything in ResultData, which we can pass around
    // var occurrances = std.StringArrayHashMap(u64).init(allocator);
    var occurrances = std.StringArrayHashMap(u64).init(allocator);
    var interestingGames = std.ArrayList(InterestingGame).init(allocator);
    var arena = std.heap.ArenaAllocator.init(allocator);
    var result = ResultData{
        .occurrances = &occurrances,
        .interestingGames = &interestingGames,
        .allocator = allocator,
        .arena = &arena,
        .arenaAllocator = arena.allocator(),
    };
    defer result.deinit();

    const startTime = std.time.milliTimestamp();

    var msg_buf: [maxGameSize]u8 = undefined;
    while (try r.readUntilDelimiterOrEof(&msg_buf, '\n')) |line| {
        result.bytesTotal += line.len;
        if (!std.mem.startsWith(u8, line, "1. ")) {
            // either empty, an annotation, or abandoned game like "0-1"
            continue;
        }
        result.bytesFromGames += line.len;

        try Parse.extractMoves(line, &result);
        std.debug.assert(std.mem.endsWith(u8, line, "0-1") or std.mem.endsWith(u8, line, "1-0") or std.mem.endsWith(u8, line, "1/2-1/2") or std.mem.endsWith(u8, line, "*"));

        // Print progress occasionally
        // Unfortunately since we read buffered from stdin we don't know how much data will come so we can't print a percentage.
        // But it'd be too much data if we read all the stdin to a buffer first.
        if (result.numGames % 1000 == 0) {
            clearCurrentLine();
            const lastMove = result.interestingGames.getLastOrNull();
            const dt = @divTrunc((std.time.milliTimestamp() - startTime), 1000);
            log("games processed: {} ({} games/sec)     {} interesting games     most recent {s}\r", .{
                fmtComma(result.numGames),
                fmtComma(if (dt > 0) @divTrunc(@as(i64, @intCast(result.numGames)), dt) else 0),
                fmtComma(result.interestingGames.items.len),
                if (lastMove != null) @tagName(lastMove.?.type) else "",
            });
        }
    }

    log("\n", .{});
    log("\n", .{});

    const elapsed = @divTrunc((std.time.milliTimestamp() - startTime), 1000);
    log("finished in {}, with {} unique moves from {} games\n", .{ fmtTimeSec(elapsed), fmtComma(occurrances.count()), fmtComma(result.numGames) });

    util.sortMovesByFrequency(&occurrances);
    try json.writeResultJson(allocator, &result, null);
}

const maxGameSize = 0x10000;

pub fn trim(comptime T: type, slice: []T, values_to_strip: []const T) []T {
    var begin: usize = 0;
    var end: usize = slice.len;
    while (begin < end and std.mem.indexOfScalar(T, values_to_strip, slice[begin]) != null) : (begin += 1) {}
    while (end > begin and std.mem.indexOfScalar(T, values_to_strip, slice[end - 1]) != null) : (end -= 1) {}
    return slice[begin..end];
}
