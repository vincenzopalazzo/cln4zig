/// JSON RPC 2.0 implementation in pure Zig language
///
/// This library is spec complainant https://www.jsonrpc.org/specification
///
/// author: https://github.com/vincenzopalazzo
const net = @import("std").net;
const json = @import("std").json;
const std = @import("std");

const myjson = @import("../json/json.zig");

pub const RPCError = struct {
    code: u64,
    message: []const u8,
    data: ?json.Value = null,
};

pub const Request = struct {
    id: ?json.Value = null,
    jsonrpc: []const u8,
    method: []const u8,
    params: json.Value,
};

pub const RPCResponse = struct {
    id: ?json.Value = null,
    result: ?json.Value = null,
    err: ?RPCError = null,
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

    pub fn buildSuccess(allocator: std.mem.Allocator, id: ?json.Value, result: json.Value) !json.Value {
        var request_tree = json.ObjectMap.init(allocator);
        if (id) |i| {
            try request_tree.put("id", i);
        }
        try request_tree.put("jsonrpc", json.Value{ .string = "2.0" });
        try request_tree.put("result", result);

        return json.Value{ .object = request_tree };
    }

    pub fn buildError(allocator: std.mem.Allocator, id: ?json.Value, err: *const RPCError) !json.Value {
        var request_tree = json.ObjectMap.init(allocator);
        if (id) |i| {
            try request_tree.put("id", i);
        }

        try request_tree.put("jsonrpc", json.Value{ .string = "2.0" });

        var jsonErr = try myjson.marshall(allocator, err);
        try request_tree.put("error", jsonErr);

        return json.Value{ .object = request_tree };
    }

    fn read(self: *Self, comptime T: type, allocator: std.mem.Allocator) !T {
        var reader = self.stream.reader();
        var buffer = std.ArrayList(u8).init(allocator);
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

pub fn CoreLNUnix(path: []const u8) !CLNUnix {
    return CLNUnix{
        .socket = JSONRPC{
            .version = "2.0",
            .stream = try net.connectUnixSocket(path),
        },
    };
}

pub const CLNUnix = struct {
    const Self = @This();

    /// The Unix socket with the path linked.
    socket: JSONRPC,

    pub fn call(self: *Self, comptime T: type, allocator: std.mem.Allocator, method: []const u8, payload: json.ObjectMap) !T {
        return try self.socket.call(T, allocator, "1", method, payload);
    }
};
