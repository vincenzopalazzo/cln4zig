/// Simple json module to have a simple API to
/// do simple operation like marshall and unmarshall.
///
/// Author: Vincenzo Palazzo <vincenzopalazzo@member.fsf.org>
const std = @import("std");

/// marshall a json value from a `anytype` type.
pub fn marshall(allocator: std.mem.Allocator, buffer: anytype) !std.json.Value {
    var buff = std.ArrayList(u8).init(allocator);
    _ = try std.json.stringify(buffer, .{}, buff.writer());

    var json = try std.json.parseFromSlice(std.json.Value, allocator, buff.items, .{});
    return json.value;
}
