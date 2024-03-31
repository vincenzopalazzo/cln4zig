// Built in RPC method for core ligtning plugins
//
// For more info please see: https://docs.corelightning.org/docs/a-day-in-the-life-of-a-plugin
const std = @import("std");
const json = std.json;

const jsonrpc = @import("./json_rpc/rpc_two.zig");
const cln = @import("./plugin.zig");
const myjson = @import("./json/json.zig");

/// `getmanifest` asks the plugin for command line options and JSON-RPC commands
/// that should be passed through. This can be run before lightningd checks that it
/// is the sole user of the lightning-dir directory (for --help) so your plugin should
/// not touch files at this point.
pub fn GetManifest(allocator: std.mem.Allocator, plugin: *cln.Plugin, _: *jsonrpc.Request) !jsonrpc.RPCResponse {
    var response = json.ObjectMap.init(allocator);
    // Fill all the information here

    var methods = std.ArrayList(json.Value).init(allocator);
    try response.put("options", json.Value{ .array = methods });
    try response.put("subscriptions", json.Value{ .array = methods });
    try response.put("hooks", json.Value{ .array = methods });

    var iterator = plugin.rpcInfo.valueIterator();
    while (iterator.next()) |value| {
        if (std.mem.eql(u8, value.name, "getmanifest")) {
            continue;
        } else if (std.mem.eql(u8, value.name, "init")) {
            continue;
        }
        var jsonValue = try myjson.marshall(allocator, value);
        try methods.append(jsonValue);
    }
    try response.put("dynamic", json.Value{ .bool = true });
    try response.put("rpcmethods", json.Value{ .array = methods });
    return .{ .result = json.Value{ .object = response } };
}

/// `init` is called after the command line options have been parsed and passes them through
/// with the real values (if specified). This is also the signal that lightningd's JSON-RPC
/// over Unix Socket is now up and ready to receive incoming requests from the plugin.
pub fn Init(allocator: std.mem.Allocator, plugin: *cln.Plugin, request: *jsonrpc.Request) !jsonrpc.RPCResponse {
    // Decode all the basic stuff
    if (plugin.onInit) |onInit| {
        return onInit(allocator, plugin, request);
    }
    var response = json.ObjectMap.init(allocator);
    return .{ .result = json.Value{ .object = response } };
}
