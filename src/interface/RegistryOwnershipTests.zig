// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
const std = @import("std");
const api = @import("ffi/src/registry.zig");
const Context = struct {
    registry: *api.Registry,
    calls: usize = 0,
    status: c_int = 7,
    observed_borrow: bool = false,
    violate_frame: bool = false,
};
// The fixture retains the typed owner and checks the opaque identity passed by
// the real wrapper; no foreign pointer is cast or dereferenced by this harness.
var active_context: ?*Context = null;
var secondary_calls: usize = 0;
fn secondary_callback(_: ?*anyopaque, _: ?[*]const u8, _: usize) callconv(.c) c_int {
    secondary_calls += 1;
    return 3;
}
fn callback(raw: ?*anyopaque, bytes: ?[*]const u8, len: usize) callconv(.c) c_int {
    const ctx = active_context orelse return 6;
    if (raw != @as(?*anyopaque, ctx)) return 6;
    ctx.calls += 1;
    ctx.observed_borrow = ctx.registry.active and len == 3 and bytes != null;
    if (bytes) |p| ctx.observed_borrow = ctx.observed_borrow and p[0] == 0 and p[1] == 13 and p[2] == 255;
    // Only supported public operations here; neither may mutate a busy registry.
    ctx.observed_borrow = ctx.observed_borrow and api.uaa_registry_unregister(ctx.registry, 9) == 6;
    ctx.observed_borrow = ctx.observed_borrow and api.uaa_registry_register(ctx.registry, 9, callback, raw) == 6;
    if (ctx.violate_frame) ctx.registry.rest = null;
    return ctx.status;
}

test "actual wrapper restores idle and endpoint identities on all normal exits" {
    const registry = api.uaa_registry_create() orelse return error.OutOfMemory;
    defer _ = api.uaa_registry_destroy(registry);
    var context = Context{ .registry = registry };
    active_context = &context;
    defer active_context = null;
    secondary_calls = 0;
    var other = Context{ .registry = registry };
    const payload = [_]u8{ 0, 13, 255 };
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 1, callback, &context));
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 9, secondary_callback, &other));
    const before = registry.*;
    try std.testing.expectEqual(@as(c_int, 4), api.uaa_registry_call(registry, 1, null, 3));
    try std.testing.expectEqual(@as(usize, 0), context.calls);
    try std.testing.expectEqualDeep(before, registry.*);
    for ([_]c_int{ -2147483648, -1, 0, 7, 11, 12, 2147483647 }) |status| {
        context.status = status;
        const expected: c_int = if (status >= 0 and status <= 11) status else 6;
        try std.testing.expectEqual(expected, api.uaa_registry_call(registry, 1, &payload, payload.len));
        try std.testing.expect(context.observed_borrow);
        try std.testing.expectEqualDeep(before, registry.*);
    }
    try std.testing.expectEqual(@as(usize, 7), context.calls);
    try std.testing.expectEqual(@as(usize, 0), other.calls);
    try std.testing.expectEqual(@as(usize, 0), secondary_calls);
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_unregister(registry, 1));
    try std.testing.expectEqual(@as(c_int, 11), api.uaa_registry_call(registry, 1, &payload, payload.len));
}

test "raw alias counterexample demonstrates necessity of the callback frame premise" {
    const registry = api.uaa_registry_create() orelse return error.OutOfMemory;
    defer _ = api.uaa_registry_destroy(registry);
    var context = Context{ .registry = registry, .violate_frame = true };
    active_context = &context;
    defer active_context = null;
    const payload = [_]u8{ 0, 13, 255 };
    try std.testing.expectEqual(@as(c_int, 0), api.uaa_registry_register(registry, 9, callback, &context));
    try std.testing.expect(registry.rest != null);
    try std.testing.expectEqual(@as(c_int, 7), api.uaa_registry_call(registry, 9, &payload, payload.len));
    try std.testing.expect(context.observed_borrow);
    try std.testing.expect(!registry.active);
    // This is the EXPECTED counterexample, not an ownership safety pass.
    try std.testing.expect(registry.rest == null);
    try std.testing.expectEqual(@as(c_int, 11), api.uaa_registry_call(registry, 9, &payload, payload.len));
}
