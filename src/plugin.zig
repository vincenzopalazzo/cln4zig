/// Core lightning plugin implementation
///
/// Author: Vincenzo Palazzo <vincenzopalazzo@member.fsf.org>
const std = @import("std");
const net = @import("std").net;
const json = @import("std").json;
const io = @import("std").io;

const jsonrpc = @import("./json_rpc/rpc_two.zig");
const builtin = @import("./builtin.zig");

pub const Plugin = struct {
    const Self = @This();
    pub const CallbackFn = *const fn (std.mem.Allocator, *Self, *jsonrpc.Request) anyerror!jsonrpc.RPCResponse;
    pub const RPCInfo = struct {
        name: []const u8,
        usage: []const u8,
        description: []const u8,
        long_description: []const u8,
        deprecated: bool,
    };

    rpcMethod: std.StringHashMap(CallbackFn),
    rpcInfo: std.StringHashMap(RPCInfo),
    onInit: ?CallbackFn = null,
    rpc: ?jsonrpc.CLNUnix = null,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return Self{
            .rpcMethod = std.StringHashMap(CallbackFn).init(allocator),
            .rpcInfo = std.StringHashMap(RPCInfo).init(allocator),
        };
    }

    pub fn rpc(self: *Self) !jsonrpc.CLNUnix {
        return self.rpc orelse return error.NotFound;
    }

    // Add an RPC method
    pub fn addMethod(self: *Self, name: []const u8, description: []const u8, callback: CallbackFn) !void {
        try self.rpcMethod.put(name, callback);
        try self.rpcInfo.put(name, .{ .name = name, .description = description, .long_description = description, .usage = "", .deprecated = false });
    }

    pub fn callMethod(self: *Self, allocator: std.mem.Allocator, request: *jsonrpc.Request) !jsonrpc.RPCResponse {
        var callbackName = request.method;
        var callback = self.rpcMethod.get(callbackName) orelse return error.NotFound;
        return callback(allocator, self, request);
    }

    pub fn notfy(_: *Self, request: *jsonrpc.Request) !void {
        _ = request.method;
    }

    fn parseJson(comptime T: type, allocator: std.mem.Allocator, buff: []const u8) !T {
        var parse = try json.parseFromSliceLeaky(T, allocator, buff, .{
            .ignore_unknown_fields = true,
        });
        return parse;
    }

    fn handleReponse(allocator: std.mem.Allocator, response: *jsonrpc.RPCResponse) !json.Value {
        var pluginResponse: json.Value = undefined;
        if (response.result) |result| {
            pluginResponse = try jsonrpc.JSONRPC.buildSuccess(allocator, response.id, result);
        } else if (response.err) |err| {
            pluginResponse = try jsonrpc.JSONRPC.buildError(allocator, response.id, &err);
        } else {
            unreachable;
        }
        return pluginResponse;
    }

    pub fn start(self: *Self) !void {
        // 1. Get a I/O writer
        const stdin = io.getStdIn().reader();
        const stdout = io.getStdOut().writer();
        // 2. register the default method
        try self.addMethod("init", "", builtin.Init);
        try self.addMethod("getmanifest", "", builtin.GetManifest);

        // Open the file for writing. This will create the file if it doesn't exist or truncate it if it does.
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        var allocator = arena.allocator();
        defer arena.deinit();

        // 3. Listen for new call
        // FIXME: we should block there or run async stuff, otherwise
        // we iterate also when we are not used by cln
        while (true) {
            var input = std.ArrayList(u8).init(allocator);
            try stdin.streamUntilDelimiter(input.writer(), '\n', null);

            const whitespace = " \n\t";
            if (std.mem.trim(u8, input.items, whitespace).len == 0) {
                continue;
            }

            // 4. Parse the value inside a json request
            var request = try Self.parseJson(jsonrpc.Request, allocator, input.items);
            // 5. call the method or the notification
            if (request.id == null) {
                try self.notfy(&request);
                continue;
            }

            var response = try self.callMethod(allocator, &request);

            response.id = request.id;
            var jsonResult = try Self.handleReponse(allocator, &response);
            // 6. Return the response
            var out = std.ArrayList(u8).init(allocator);
            _ = try json.stringify(jsonResult, .{}, out.writer());

            try stdout.print("{s}\n", .{try out.toOwnedSlice()});
        }
    }
};

test "check simple json parsing" {
    const assert = std.debug.assert;

    const string =
        \\ {"jsonrpc":"2.0","id":1743,"method":"getmanifest","params":{"allow-deprecated-apis":true}}
    ;
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var allocator = arena.allocator();
    defer arena.deinit();

    var request = try Plugin.parseJson(jsonrpc.Request, allocator, string);
    assert(std.mem.eql(u8, request.method, "getmanifest"));
}
