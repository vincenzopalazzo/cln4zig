/// Core lightning Client implementation
///
/// author: https://github.com/vincenzopalazzo
const std = @import("std");
const net = @import("std").net;
const json = @import("std").json;

const jsonrpc = @import("./json_rpc/rpc_two.zig");

pub fn CoreLNUnix(path: []const u8) !CLNUnix {
    return CLNUnix{
        .socket = jsonrpc.JSONRPC{
            .version = "2.0",
            .stream = try net.connectUnixSocket(path),
        },
    };
}

const CLNUnix = struct {
    const Self = @This();

    /// The Unix socket with the path linked.
    socket: jsonrpc.JSONRPC,

    pub fn call(self: *Self, comptime T: type, allocator: std.mem.Allocator, method: []const u8, payload: json.ObjectMap) !T {
        return try self.socket.call(T, allocator, "1", method, payload);
    }
};

test "call a local core lightning node: Test 1" {
    const os = std.os;

    const GetInfo = struct {
        id: []const u8,
    };

    const unix_path = os.getenv("CLN_UNIX") orelse return error.skip;
    var client: CLNUnix = try CoreLNUnix(unix_path);

    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var request = json.ObjectMap.init(allocator.allocator());
    _ = try client.call(GetInfo, allocator.allocator(), "getinfo", request);
}
