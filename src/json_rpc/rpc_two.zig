/// JSON RPC 2.0 implementation in pure Zig language
///
/// This library is spec complainant https://www.jsonrpc.org/specification
///
/// author: https://github.com/vincenzopalazzo
const net = @import("std").net;
const json = @import("std").json;
const std = @import("std");

pub const JSONRPC = struct {
    const Self = @This();

    stream: net.Stream,
    version: []const u8,

    pub fn call(self: *Self, id: []const u8, method: []const u8, payload: json.ObjectMap) !json.Value {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();
        var to_stream = try self.build_message(&arena, id, method, payload);
        _ = try self.stream.write(to_stream);
        return self.read(&arena);
    }

    fn build_message(self: *Self, arena: *std.heap.ArenaAllocator, id: []const u8, method: []const u8, payload: json.ObjectMap) ![]const u8 {
        const allocator = arena.allocator();
        var request_tree = json.ObjectMap.init(allocator);
        defer request_tree.deinit();
        try request_tree.put("id", std.json.Value{ .String = id });
        try request_tree.put("jsonrpc", std.json.Value{ .String = self.version });
        try request_tree.put("method", std.json.Value{ .String = method });
        try request_tree.put("params", std.json.Value{ .Object = payload });

        var str = std.ArrayList(u8).init(allocator);
        try json.stringify(json.Value{ .Object = request_tree }, .{}, str.writer());
        return str.items;
    }

    fn read(self: *Self, arena: *std.heap.ArenaAllocator) !json.Value {
        var reader = self.stream.reader();
        var buffer = std.ArrayList(u8).init(arena.allocator());
        defer buffer.deinit();
        try reader.readUntilDelimiterArrayList(&buffer, '\n', 40000);
        var parser = std.json.Parser.init(arena.allocator(), false);
        defer parser.deinit();
        var string = buffer.toOwnedSlice();
        std.debug.print("{s}\n", .{string});
        std.debug.assert(std.json.validate(string) == true);
        var json_tree = try parser.parse(string);
        defer json_tree.deinit();
        return json_tree.root;
    }
};

test "check parser function" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var parser = std.json.Parser.init(arena.allocator(), false);
    defer parser.deinit();

    var string =
        \\ {"jsonrpc":"2.0","id":"1","result":{"id":"03b39d1ddf13ce486de74e9e44e0538f960401a9ec75534ba9cfe4100d65426880",
        \\ "alias":"SLICKERGOPHER-testnet","color":"02bf81","num_peers":20,"num_pending_channels":1,"num_active_channels":22,
        \\ "num_inactive_channels":0,"address":[{"type":"torv3","address":
        \\ "iopzsfi3pbtrimnovncctjthmot7nb6pvh2swr6pqvizmisy4ts62lid.onion","port":19735}],"binding":[{"type":"ipv4",
        \\ "address":"127.0.0.1","port":19735}],"version":"v0.12.0rc3-4-g3ce2673-modded","blockheight":2344351,
        \\ "network":"testnet","fees_collected_msat":30021,"lightning-dir":"/media/vincent/VincentSSD/.lightning/testnet",
        \\ "our_features":{"init":"08a080282269a2","node":"88a080282269a2","channel":"","invoice":"02000020024100"}}}
    ;
    _ = try parser.parse(string);
}

pub const ResponseObj = struct {
    id: ?[]const u8,
    jsonrpc: []const u8,
    errors: ?json.ObjectMap,
    result: ?json.ObjectMap,
};
