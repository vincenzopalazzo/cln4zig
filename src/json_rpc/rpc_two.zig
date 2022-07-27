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
        //defer arena.deinit();
        var to_stream = try self.build_message(&arena, id, method, payload);
        _ = try self.stream.write(to_stream);
        return self.read(&arena);
    }

    fn build_message(self: *Self, arena: *std.heap.ArenaAllocator, id: []const u8, method: []const u8, payload: json.ObjectMap) ![]const u8 {
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

    fn read(self: *Self, arena: *std.heap.ArenaAllocator) !json.Value {
        var reader = self.stream.reader();
        var buffer = std.ArrayList(u8).init(arena.allocator());
        defer buffer.deinit();
        while (true) {
            const size_buffer = 64;
            var tmp_buffer: [64]u8 = undefined;
            var byte_read = reader.read(&tmp_buffer) catch unreachable;
            // FIXME: if the read byte is less of the buffer we got stuck in the read
            // if (byte_read == 0) {
            //     std.debug.print("{s}\n", .{"end buffer"});
            //     break;
            // }
            buffer.appendSlice(&tmp_buffer) catch unreachable;
            if (byte_read < size_buffer) {
                try buffer.append(tmp_buffer[byte_read - 1]);
                break;
            }
        }
        var string = buffer.allocatedSlice();
        var clean_string = std.ArrayList(u8).init(arena.allocator());
        for (string) |char, index| {
            if (char == '\n' and (index > 0 and string[index - 1] == '\n')) {
                break;
            } else if (char == '\n') {
                continue;
            }
            try clean_string.append(char);
        }
        string = clean_string.allocatedSlice();
        var parser = std.json.Parser.init(arena.allocator(), false);
        defer parser.deinit();
        std.debug.print("{s}", .{string});
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
        \\ "alias":"SLICKERGOPHER-testnet","color":"02bf81","num_peers":17,"num_pending_channels":1,"num_active_channels":16,
        \\ "num_inactive_channels":0,"address":[{"type":"torv3","address":"iopzsfi3pbtrimnovncctjthmot7nb6pvh2swr6pqvizmisy4ts62lid.onion","port":19735}],
        \\ "binding":[{"type":"ipv4","address":"127.0.0.1","port":9735}],"version":"0.10.2","blockheight":2282149,
        \\ "network":"testnet","msatoshi_fees_collected":30021,"fees_collected_msat":"30021msat",
        \\ "lightning-dir":"/media/vincent/VincentSSD/.lightning/testnet"} }
    ;
    _ = try parser.parse(string);
}

pub const ResponseObj = struct {
    id: ?[]const u8,
    jsonrpc: []const u8,
    //errors: ?json.ObjectMap,
    result: ?json.ObjectMap,
};
