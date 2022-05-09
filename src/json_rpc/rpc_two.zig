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

    pub fn call(self: *Self, id: []const u8, method: []const u8, payload: []const u8) !u64 {
        var to_stream = try self.build_message(id, method, payload);
        return self.stream.write(to_stream);
    }

    fn build_message(self: *Self, id: []const u8, method: []const u8, payload: []const u8) ![]const u8 {
        var buf: [100]u8 = undefined;
        var fba = std.heap.FixedBufferAllocator.init(&buf);
        var string = std.ArrayList(u8).init(fba.allocator());
        const request = RequestObj{
            .id = id,
            .jsonrpc = self.version,
            .method = method,
            .payload = payload,
        };
        try json.stringify(request, .{}, string.writer());
        return string.items;
    }
};

const RequestObj = struct {
    id: []const u8,
    jsonrpc: []const u8,
    method: []const u8,
    payload: []const u8,
};
