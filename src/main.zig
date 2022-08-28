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
            .stream = net.connectUnixSocket(path) catch unreachable,
        },
    };
}

const CLNUnix = struct {
    const Self = @This();

    /// The Unix socket with the path linked.
    socket: jsonrpc.JSONRPC,

    pub fn call(self: *Self, method: []const u8, payload: json.ObjectMap) !json.Value {
        return try self.socket.call("1", method, payload);
    }
};

const Mock = struct {
    a: u8,
    b: u8,
};

test "try to call core lightning Unix RPC method" {
    const os = @import("std").os;

    const unix_path = os.getenv("CLN_UNIX") orelse unreachable;
    var client: CLNUnix = CoreLNUnix(unix_path) catch {
        return;
    };
    var allocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    _ = try client.call("getinfo", json.ObjectMap.init(allocator.allocator()));
}
