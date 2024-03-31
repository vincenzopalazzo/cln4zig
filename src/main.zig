// Core lightning Client implementation
//
// author: https://github.com/vincenzopalazzo
const std = @import("std");
const json = std.json;

const cln = @import("./plugin.zig");
const jsonrpc = @import("./json_rpc/rpc_two.zig");

fn SayHello(allocator: std.mem.Allocator, _: *cln.Plugin, _: *jsonrpc.Request) !jsonrpc.RPCResponse {
    var result = json.ObjectMap.init(allocator);
    try result.put("msg", json.Value{ .string = "hello from Zig" });
    return .{ .result = json.Value{ .object = result } };
}
/// First example of plugin
pub fn main() anyerror!void {
    // A plugin need a global allocator
    // to keep safe the global state of the plugin.
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();
    var plugin = try cln.Plugin.init(allocator);

    try plugin.addMethod("hello", "", SayHello);
    try plugin.start();
}

test "call a local core lightning node: Test 1" {
    const os = std.os;

    const GetInfo = struct {
        id: []const u8,
    };

    const unix_path = os.getenv("CLN_UNIX") orelse return error.skip;
    var client: jsonrpc.CLNUnix = try jsonrpc.CoreLNUnix(unix_path);

    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var request = json.ObjectMap.init(allocator.allocator());
    _ = try client.call(GetInfo, allocator.allocator(), "getinfo", request);
}
