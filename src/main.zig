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