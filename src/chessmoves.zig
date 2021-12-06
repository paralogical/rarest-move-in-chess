const std = @import("std");
const Allocator = std.mem.Allocator;
const analyze = @import("./analyze.zig").analyze;
const collectStdin = @import("./collect.zig").collectStdin;

fn usage(executable: ?[]const u8) void {
    const exe: []const u8 = executable orelse "chessmoves";
    std.debug.print("Usage: {s} collect\n", .{exe});
    std.debug.print("   Parse pgn data from stdin for all moves,\n", .{});
    std.debug.print("   Will print json with sorted move:count output\n", .{});
    std.debug.print("Usage: {s} analyze <result.json> <result2.json> <folderWithResults/>\n", .{exe});
    std.debug.print("   Combine and analayze collected moves from `collect` command \n", .{});
}

pub fn main() anyerror!void {
    const allocator = std.heap.page_allocator;

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    const executable = args[0];
    if (args.len < 2) {
        usage(executable);
        return;
    }

    const command = args[1];
    if (std.mem.eql(u8, command, "collect")) {
        if (args.len == 2) { // executable, "collect"
            try collectStdin();
            return;
        }
        usage(executable);
        return;
    } else if (std.mem.eql(u8, command, "analyze")) {
        if (args.len != 3) { // executable, "analyze", filename
            usage(executable);
            return;
        }
        const directory = args[2];
        try analyze(directory);
    }
}

test {
    _ = @import("./analyze.zig");
    _ = @import("./util.zig");
}
