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
        var to_stream = try self.build_message(id, method, payload);
        _ = try self.stream.write(to_stream);
        return self.read();
    }

    fn build_message(self: *Self, id: []const u8, method: []const u8, payload: json.ObjectMap) ![]const u8 {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();
        var request_tree = json.ObjectMap.init(allocator);
        try request_tree.put("id", std.json.Value{ .String = id });
        try request_tree.put("jsonrpc", std.json.Value{ .String = self.version });
        try request_tree.put("method", std.json.Value{ .String = method });
        try request_tree.put("params", std.json.Value{ .Object = payload });

        var str = std.ArrayList(u8).init(allocator);
        try json.stringify(json.Value{ .Object = request_tree }, .{}, str.writer());
        return str.items;
    }

    fn read(self: *Self) !json.Value {
        var reader = self.stream.reader();
        var buffer: [4096]u8 = undefined;
        _ = try reader.read(&buffer);
        std.debug.print("{s}", .{buffer});
        const allocator = std.heap.page_allocator;
        var parser = std.json.Parser.init(allocator, false);
        defer parser.deinit();

        var json_tree = try parser.parse(&buffer);
        return json_tree.root;
    }
};

pub const ResponseObj = struct {
    id: ?u64,
    jsonrpc: []const u8,
    errors: ?json.ObjectMap,
    result: json.ObjectMap,
};
