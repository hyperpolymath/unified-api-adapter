// SPDX-License-Identifier: MPL-2.0
// Copyright (c) 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Pure state transitions used by the actual registry FFI. Endpoint values
// retain callback/context identity; ownership of their pointees is external.
pub const Slot = enum { mcp, rest };

pub fn State(comptime E: type) type {
    return struct { rest: ?E = null, mcp: ?E = null, active: bool = false };
}
pub fn Reply(comptime E: type) type {
    return struct { status: u8, next: State(E), selected: ?E = null };
}
pub fn get(comptime E: type, s: State(E), slot: Slot) ?E {
    return switch (slot) { .mcp => s.mcp, .rest => s.rest };
}
pub fn put(comptime E: type, s: State(E), slot: Slot, endpoint: ?E) State(E) {
    return switch (slot) {
        .mcp => .{ .rest = s.rest, .mcp = endpoint, .active = s.active },
        .rest => .{ .rest = endpoint, .mcp = s.mcp, .active = s.active },
    };
}
pub fn mark(comptime E: type, s: State(E), active: bool) State(E) {
    return .{ .rest = s.rest, .mcp = s.mcp, .active = active };
}
pub fn register(comptime E: type, s: State(E), slot: Slot, endpoint: E) Reply(E) {
    if (s.active) return .{ .status = 6, .next = s };
    if (get(E, s, slot) != null) return .{ .status = 9, .next = s };
    return .{ .status = 0, .next = put(E, s, slot, endpoint) };
}
pub fn unregister(comptime E: type, s: State(E), slot: Slot) Reply(E) {
    if (s.active) return .{ .status = 6, .next = s };
    if (get(E, s, slot) == null) return .{ .status = 8, .next = s };
    return .{ .status = 0, .next = put(E, s, slot, null) };
}
pub fn begin(comptime E: type, s: State(E), slot: Slot) Reply(E) {
    if (s.active) return .{ .status = 6, .next = s };
    const endpoint = get(E, s, slot) orelse return .{ .status = 11, .next = s };
    return .{ .status = 0, .next = mark(E, s, true), .selected = endpoint };
}
pub fn finish(comptime E: type, s: State(E)) State(E) {
    return mark(E, s, false);
}
pub fn sanitize(status: c_int) c_int {
    return if (status >= 0 and status <= 11) status else 6;
}
