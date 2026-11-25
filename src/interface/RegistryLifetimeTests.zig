// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
const std = @import("std");
const api = @import("ffi/src/registry.zig");

const Context = struct {
    registry: *api.Registry,
    calls: usize = 0,
    refusals_ok: bool = true,
};
var current: ?*Context = null;
var callback_entries: usize = 0;

fn callback(raw: ?*anyopaque, bytes: ?[*]const u8, len: usize) callconv(.c) c_int {
    callback_entries += 1;
    const context = current orelse return 6;
    if (raw != @as(?*anyopaque, context)) return 6;
    const input = bytes orelse return 4;
    if (len != 2) return 4;
    if (input[0] != 11 or input[1] != 22) return 4;
    context.calls += 1;
    context.refusals_ok = context.refusals_ok and api.uaa_registry_destroy(context.registry) == 6;
    context.refusals_ok = context.refusals_ok and api.uaa_registry_call(context.registry, 9, bytes, len) == 6;
    context.refusals_ok = context.refusals_ok and api.uaa_registry_unregister(context.registry, 9) == 6;
    context.refusals_ok = context.refusals_ok and api.uaa_registry_register(context.registry, 9, callback, raw) == 6;
    return 0;
}

test "shared context stays retained until each registration is detached" {
    var owner: ?*api.Registry = api.uaa_registry_create() orelse return error.OutOfMemory;
    defer { if (owner) |registry| { _ = api.uaa_registry_destroy(registry); } }
    const registry = owner.?;
    const context = try std.testing.allocator.create(Context);
    defer std.testing.allocator.destroy(context);
    context.* = .{ .registry = registry };
    current = context;
    callback_entries = 0;
    defer current = null;
    const input = [_]u8{ 11, 22 };
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 1, callback, context));
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 9, callback, context));
    try std.testing.expectEqual(@as(c_int, 9), api.uaa_registry_register(registry, 9, callback, context));
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_call(registry, 1, &input, input.len));
    try std.testing.expect(context.refusals_ok);
    try std.testing.expect(!registry.active);
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_unregister(registry, 1));
    try std.testing.expectEqual(@as(c_int, 11), api.uaa_registry_call(registry, 1, &input, input.len));
    // The other registration still retains the same caller-owned context.
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_call(registry, 9, &input, input.len));
    try std.testing.expectEqual(@as(usize, 2), context.calls);
    try std.testing.expectEqual(@as(usize, 2), callback_entries);
    try std.testing.expect(context.refusals_ok);
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_unregister(registry, 9));
    try std.testing.expectEqual(@as(c_int, 8), api.uaa_registry_unregister(registry, 9));
    try std.testing.expectEqual(@as(c_int, 11), api.uaa_registry_call(registry, 9, &input, input.len));
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_destroy(registry));
    owner = null;
    // Destroying the registry did not destroy the caller's context allocation.
    context.calls += 1;
    try std.testing.expectEqual(@as(usize, 3), context.calls);
}

test "idle destroy detaches installed endpoints without destroying context" {
    var owner: ?*api.Registry = api.uaa_registry_create() orelse return error.OutOfMemory;
    defer { if (owner) |registry| { _ = api.uaa_registry_destroy(registry); } }
    const registry = owner.?;
    const context = try std.testing.allocator.create(Context);
    defer std.testing.allocator.destroy(context);
    context.* = .{ .registry = registry };
    current = context;
    callback_entries = 0;
    defer current = null;
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 1, callback, context));
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 9, callback, context));
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_destroy(registry));
    owner = null;
    try std.testing.expectEqual(@as(usize, 0), callback_entries);
    context.calls = 17;
    try std.testing.expectEqual(@as(usize, 17), context.calls);
    try std.testing.expectEqual(@as(c_int, 4), api.uaa_registry_destroy(null));
    // No stale pointer is used; the ABI cannot safely validate arbitrary bits.
}
