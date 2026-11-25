// SPDX-License-Identifier: MPL-2.0
const std = @import("std");
const source = @import("registry_state.zig");
const E = u32;
fn step(op: u8, slot: source.Slot, s: source.State(E)) source.Reply(E) {
    return switch (op) {
        0 => source.register(E, s, slot, 11),
        1 => source.register(E, s, slot, 22),
        2 => source.unregister(E, s, slot),
        3 => source.begin(E, s, slot),
        else => .{ .status = 0, .next = source.finish(E, s) },
    };
}
pub fn main() !void {
    var buf: [256]u8 = undefined;
    const endpoints = [_]?E{ null, 11, 22 };
    for (endpoints) |r| {
        for (endpoints) |m| {
            for ([_]bool{ false, true }) |busy| {
                for ([_]source.Slot{ .rest, .mcp }) |slot| {
                    for (0..5) |a| {
                        for (0..5) |z| {
                            const first = step(@intCast(a), slot, .{ .rest = r, .mcp = m, .active = busy });
                            const second = step(@intCast(z), slot, first.next);
                            const line = try std.fmt.bufPrint(&buf, "{d} {d} {d} {d} {d} {d} {d} {d} {d} {d}\n", .{
                                first.status, first.next.rest orelse 0, first.next.mcp orelse 0, @intFromBool(first.next.active), first.selected orelse 0,
                                second.status, second.next.rest orelse 0, second.next.mcp orelse 0, @intFromBool(second.next.active), second.selected orelse 0,
                            });
                            try std.fs.File.stdout().writeAll(line);
                        }
                    }
                }
            }
        }
    }
    for ([_]c_int{ -2147483648, -1, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 256, 2147483647 }) |z| {
        const line = try std.fmt.bufPrint(&buf, "status {d} {d}\n", .{ z, source.sanitize(z) });
        try std.fs.File.stdout().writeAll(line);
    }
}

