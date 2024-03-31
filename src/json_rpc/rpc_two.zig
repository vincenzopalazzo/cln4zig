/// JSON RPC 2.0 implementation in pure Zig language
///
/// This library is spec complainant https://www.jsonrpc.org/specification
///
/// author: https://github.com/vincenzopalazzo
const net = @import("std").net;
const json = @import("std").json;
const std = @import("std");

pub const RPCError = struct {
    code: u64,
    message: []const u8,
    data: ?json.Value = null,
};

pub const JSONRPC = struct {
    const Self = @This();

    stream: net.Stream,
    version: []const u8,
    /// We use this variable as a global variable to
    /// Store last error that we have from a call.
    ///
    /// Curently in zig is complex return a detailed message,
    /// so we use this way.
    err: ?RPCError = null,

    pub fn call(self: *Self, comptime T: type, allocator: std.mem.Allocator, id: []const u8, method: []const u8, payload: json.ObjectMap) !T {
        var to_stream = try self.buildRequest(allocator, id, method, payload);

        var str = std.ArrayList(u8).init(allocator);
        // FIXME: make the writer a generic one.
        try json.stringify(to_stream, .{}, str.writer());

        _ = try self.stream.write(str.items);

        return self.read(T, allocator);
    }

    fn buildRequest(self: *Self, allocator: std.mem.Allocator, id: []const u8, method: []const u8, payload: json.ObjectMap) !json.Value {
        var request_tree = json.ObjectMap.init(allocator);

        try request_tree.put("id", json.Value{ .string = id });
        try request_tree.put("jsonrpc", json.Value{ .string = self.version });
        try request_tree.put("method", json.Value{ .string = method });
        try request_tree.put("params", json.Value{ .object = payload });

        return json.Value{ .object = request_tree };
    }

    fn read(self: *Self, comptime T: type, allocator: std.mem.Allocator) !T {
        var reader = self.stream.reader();
        var buffer = std.ArrayList(u8).init(allocator);
        defer buffer.deinit();
        try reader.readUntilDelimiterArrayList(&buffer, '\n', 40000);

        return try parseResponse(T, allocator, buffer.items);
    }

    fn parseResponse(comptime T: type, allocator: std.mem.Allocator, buffer: []const u8) !T {
        const Response = struct {
            id: ?[]const u8 = null,
            jsonrpc: []const u8,
            result: ?T = null,
            @"error": ?RPCError = null,
        };
        var response = try std.json.parseFromSlice(Response, allocator, buffer, .{
            .ignore_unknown_fields = true,
        });
        defer response.deinit();
        return response.value.result orelse error.RPCError;
    }

    /// Consuming the last error that happens during
    /// the last call.
    pub fn lastError(self: *Self) ?RPCError {
        var err = self.err;
        // after we read the value we set is to null again.
        self.err = null;
        return err;
    }
};

test "check parser function" {
    var arena = std.heap.GeneralPurposeAllocator(.{}){};
    var allocator = arena.allocator();
    const string =
        \\ {"jsonrpc":"2.0","id":"1","result":{"id":"03b39d1ddf13ce486de74e9e44e0538f960401a9ec75534ba9cfe4100d65426880",
        \\ "alias":"SLICKERGOPHER-testnet","color":"02bf81","num_peers":20,"num_pending_channels":1,"num_active_channels":22,
        \\ "num_inactive_channels":0,"address":[{"type":"torv3","address":
        \\ "iopzsfi3pbtrimnovncctjthmot7nb6pvh2swr6pqvizmisy4ts62lid.onion","port":19735}],"binding":[{"type":"ipv4",
        \\ "address":"127.0.0.1","port":19735}],"version":"v0.12.0rc3-4-g3ce2673-modded","blockheight":2344351,
        \\ "network":"testnet","fees_collected_msat":30021,"lightning-dir":"/media/vincent/VincentSSD/.lightning/testnet",
        \\ "our_features":{"init":"08a080282269a2","node":"88a080282269a2","channel":"","invoice":"02000020024100"}}}
    ;
    const GetInfo = struct {
        id: []const u8,
    };
    _ = try JSONRPC.parseResponse(GetInfo, allocator, string);
}
