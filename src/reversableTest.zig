const std = @import("std");
const List = std.ArrayList;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub const alloc = gpa.allocator();

// for (0..9) |s0| {
//     current.states[0] = s0;
//     for (0..9) |s1| {
//         if (s1 == s0) continue;
//         current.states[1] = s1;
//         for (0..9) |s2| {
//             if (s2 == s0 or s2 == s1) continue;
//             current.states[2] = s2;
//             qwe();
//         }
//     }
// }

// fn qwe(opsSet: u4) void {
//     for (1..opsSet + 4) |a| {
//         for (0..a) |b| {
//             current.ops[opsSet] = .{ .a = a, .b = b };
//             qwe(opsSet + 1);
//         }
//     }
//     if (opsSet < 5) return;
//     var bitsSet = try std.DynamicBitSet.initEmpty(alloc, 1 << 24);
//     for (0..1 << @bitSizeOf(T)) |i| {
//         const index = f(@as(T, @intCast(i)));
//         if (bitsSet.isSet(index)) {
//             std.debug.print("The function is NOT a permutation\n", .{});
//             return;
//         }
//         bitsSet.set(index);
//     }
//     std.debug.print("The function is a permutation!\n", .{});
// }
// var result = List(RevSimple()).init(alloc);
// var current = RevSimple(){};
// fn RevSimple() type {
//     return struct {
//         states: [3]u4,
//         ops: [5]struct { a: u4, b: u4 },
//     };
// }
