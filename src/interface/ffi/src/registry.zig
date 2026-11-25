// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Executable consumer of Abi.Registry. Differential execution is evidence,
// not a source/compiler refinement proof or a built-in network transport.
const std = @import("std");
const known = @import("protocol_tag.zig").known;
const state = @import("registry_state.zig");

pub const Callback = *const fn (?*anyopaque, ?[*]const u8, usize) callconv(.c) c_int;
const Endpoint = struct { callback: Callback, context: ?*anyopaque };
pub const Registry = state.State(Endpoint);

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
    const slot: state.Slot = switch (tag) {
        1 => .mcp,
        9 => .rest,
        else => return 11,
    };
    const cb = callback orelse return 4;
    const reply = state.register(Endpoint, registry.*, slot, .{ .callback = cb, .context = context });
    registry.* = reply.next;
    return reply.status;
}

pub export fn uaa_registry_unregister(r: ?*Registry, tag: u8) c_int {
    const registry = r orelse return 4;
    if (registry.active) return 6;
    if (!known(tag)) return 2;
    const slot: state.Slot = switch (tag) {
        1 => .mcp,
        9 => .rest,
        else => return 11,
    };
    const reply = state.unregister(Endpoint, registry.*, slot);
    registry.* = reply.next;
    return reply.status;
}

pub export fn uaa_registry_call(r: ?*Registry, tag: u8, bytes: ?[*]const u8, len: usize) c_int {
    const registry = r orelse return 4;
    if (registry.active) return 6;
    if (!known(tag)) return 2;
    const slot: state.Slot = switch (tag) {
        1 => .mcp,
        9 => .rest,
        else => return 11,
    };
    const reply = state.begin(Endpoint, registry.*, slot);
    if (reply.status != 0) return reply.status;
    const endpoint = reply.selected orelse return 11;
    registry.* = reply.next;
    defer registry.* = state.finish(Endpoint, registry.*);
    if (bytes == null and len != 0) return 4;
    const status = endpoint.callback(endpoint.context, bytes, len);
    // A foreign callback cannot inject an unknown ABI status.
    return state.sanitize(status);
}
