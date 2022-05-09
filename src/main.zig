/// Core lightning Client implementation
///
/// author: https://github.com/vincenzopalazzo
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

    pub fn call(self: *Self, method: []const u8, payload: []const u8) ![]const u8 {
        _ = try self.socket.call("1", method, payload);
        var stream = json.TokenStream.init("{}\n");
        return json.parse([]const u8, &stream, .{});
    }
};

test "try to call core lightning Unix RPC method" {
    const testing = @import("std").testing;
    const os = @import("std").os;
    const debug = @import("std").debug;

    const unix_path = os.getenv("CLN_UNIX") orelse "";
    var client: CLNUnix = CoreLNUnix(unix_path) catch {
        return;
    };
    _ = client.call("getinfo", "{}") catch |err| {
        debug.print("{s}", .{err});
        try testing.expect(false);
    };
}
