// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Executable consumer of Abi.Registry. Differential execution is evidence,
// not a source/compiler refinement proof or a built-in network transport.
const std = @import("std");
const known = @import("protocol_tag.zig").known;

pub const Callback = *const fn (?*anyopaque, ?[*]const u8, usize) callconv(.c) c_int;
const Endpoint = struct { callback: Callback, context: ?*anyopaque };
pub const Registry = struct {
    rest: ?Endpoint = null,
    mcp: ?Endpoint = null,
    active: bool = false,
};

// All calls on one live registry must be serialized by its owner. Callback
// code/context and input remain borrowed for the synchronous call only.
pub export fn uaa_registry_create() ?*Registry {
    const r = std.heap.c_allocator.create(Registry) catch return null;
    r.* = .{};
    return r;
}

pub export fn uaa_registry_destroy(r: ?*Registry) c_int {
    const registry = r orelse return 4;
    if (registry.active) return 6;
    std.heap.c_allocator.destroy(registry);
    return 0;
}

pub export fn uaa_registry_register(r: ?*Registry, tag: u8, callback: ?Callback, context: ?*anyopaque) c_int {
    const registry = r orelse return 4;
    if (registry.active) return 6;
    if (!known(tag)) return 2;
    const slot = switch (tag) {
        1 => &registry.mcp,
        9 => &registry.rest,
        else => return 11,
    };
    const cb = callback orelse return 4;
    if (slot.* != null) return 9;
    slot.* = .{ .callback = cb, .context = context };
    return 0;
}

pub export fn uaa_registry_unregister(r: ?*Registry, tag: u8) c_int {
    const registry = r orelse return 4;
    if (registry.active) return 6;
    if (!known(tag)) return 2;
    const slot = switch (tag) {
        1 => &registry.mcp,
        9 => &registry.rest,
        else => return 11,
    };
    if (slot.* == null) return 8;
    slot.* = null;
    return 0;
}

pub export fn uaa_registry_call(r: ?*Registry, tag: u8, bytes: ?[*]const u8, len: usize) c_int {
    const registry = r orelse return 4;
    if (registry.active) return 6;
    if (!known(tag)) return 2;
    const endpoint = switch (tag) {
        1 => registry.mcp,
        9 => registry.rest,
        else => null,
    } orelse return 11;
    if (bytes == null and len != 0) return 4;
    registry.active = true;
    defer registry.active = false;
    const status = endpoint.callback(endpoint.context, bytes, len);
    // A foreign callback cannot inject an unknown ABI status.
    return if (status >= 0 and status <= 11) status else 6;
}
