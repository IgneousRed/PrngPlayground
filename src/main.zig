const std = @import("std");
const lib = @import("lib.zig");
const prng = @import("prng.zig");
const dev = @import("prng_dev.zig");
const bits = @import("bits.zig");
const rand = std.rand;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

fn mulXsr64(value: u64) u64 {
    var result = value *% 0xcb45348a28cb43bd;
    return result ^ result >> 32;
}

fn mulRor64(value: u64) u64 {
    var result = value *% 0xcb45348a28cb43bd;
    return result ^ lib.ror64(result, 32);
}

fn perm32(value: u32) u32 {
    return @bitReverse(value *% 5);
}

fn mulXsr8(value: u8) u8 {
    var result = value;
    result *%= 0x35;
    result ^= result >> 4;
    result *%= 0x35;
    result ^= result >> 4;
    return result;
}

fn mulRev8(value: u8) u8 {
    var result = value;
    result *%= 0x35;
    result = @bitReverse(result);
    result *%= 0x35;
    result = @bitReverse(result);
    return result;
}

fn perm16(value: u16) u16 {
    var a = value;
    a +%= a << value % 16;
    // a ^= a >> @intCast(u4, 1);
    return a;
}

pub fn main() !void {

    // const bitSize = 2 * 5;
    // const T = bits.U(bitSize);
    // var mul: T = 5;
    // while (true) {
    //     var add: T = 1;
    //     while (true) {
    //         var good = true;
    //         var set = std.bit_set.ArrayBitSet(usize, 1 << bitSize).initEmpty();
    //         var state: T = 1;
    //         var i: usize = 0;
    //         while (i < 1 << bitSize) {
    //             var new = state *% mul;
    //             new +%= add;
    //             state = new ^ new >> bitSize / 2;
    //             if (set.isSet(state)) {
    //                 good = false;
    //                 break;
    //             }
    //             set.set(state);
    //             i += 1;
    //         }
    //         if (good) {
    //             std.debug.print("{d:0>4} {d:0>4}\n", .{ mul, add });
    //         }
    //         add +%= 2;
    //         if (add == 1) {
    //             break;
    //         }
    //     }
    //     mul +%= 8;
    //     if (mul == 5) {
    //         break;
    //     }
    // }
    // std.debug.print("Done!\n", .{});

    // a = ror(a, b);
    // a +%= f(b); (f doesn't need to be reversible)
    // a -%= f(b);
    // a ^= f(b);
    // a *%= k; (k is odd)
    // a +%= a << k;
    // a -%= a << k;
    // a ^= a << k;
    // a ^= a >> k;
    // a = @bitReverse(a);

    try childTest();
    // drawPerm(mulRev8);
    // try testHash();
    // try testMCG64();
    // permutationCheck(u16, perm16);
    // time();
}
fn childTest() !void {
    var child = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin64",
        "-tlmin",
        "10",
        "-multithreaded",
    }, alloc);
    child.stdin_behavior = .Pipe;
    // child.stdout_behavior = .Pipe;
    try child.spawn();
    const stdIn = child.stdin.?.writer();

    // var r = rand.DefaultPrng.init(0);
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            defer i += 1;
            // buf[i] = r.random().int(u64);
            buf[i] = prng.entropy64();
        }
        try stdIn.writeAll(std.mem.asBytes(&buf));
    }
}
fn drawPerm(comptime f: fn (u8) u8) void {
    var lineSpaces = [1]u8{0} ** 256;
    var i: usize = 0;
    while (i < 256) {
        defer i += 1;
        lineSpaces[f(@intCast(u8, i))] = @intCast(u8, i);
    }
    i = 255;
    while (i < 256) {
        defer i -%= 1;
        var j: usize = 0;
        while (j < lineSpaces[i]) {
            defer j += 1;
            std.debug.print(" ", .{});
        }
        std.debug.print("*\n", .{});
    }
}
fn testHash() !void {
    const stdout = std.io.getStdOut().writer();
    var counter: u64 = 0;
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            defer i += 1;
            var result = counter;
            counter += 1;
            var rounds: usize = 0;
            while (rounds < 2) {
                defer rounds += 1;
                // result = mulXsr64(result);
                result = mulRor64(result);
            }
            buf[i] = result;
        }
        try stdout.writeAll(std.mem.asBytes(&buf));
    }
}
fn testMCG64() !void {
    const stdOut = std.io.getStdOut().writer();
    var rng = prng.MCG64.new();
    // var state: u128 = 1;
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            buf[i] = rng.next64();
            // state *%= 0x2ffd4aa4540b972c007c03e5caca8a0d;
            // buf[i] = lib.ror64(@truncate(u64, state >> 64 - 6), @intCast(u6, state >> 128 - 6));
            i += 1;
        }
        try stdOut.writeAll(std.mem.asBytes(&buf));
    }
}
fn isPermutation(comptime T: type, comptime f: fn (T) T) bool {
    var bitsSet = std.DynamicBitSet.initEmpty(alloc, 1 << @bitSizeOf(T)) catch unreachable;
    var i: T = 0;
    while (true) {
        const index = f(i);
        // std.debug.print("", .{});
        if (bitsSet.isSet(index)) {
            return false;
        }
        bitsSet.set(index);
        i +%= 1;
        if (i == 0) {
            return true;
        }
    }
}
fn permutationCheck(comptime T: type, comptime f: fn (T) T) void {
    const timeStart = std.time.timestamp();
    if (isPermutation(T, f)) {
        std.debug.print("The function is a permutation!\n", .{});
    } else {
        std.debug.print("The function is NOT a permutation\n", .{});
    }
    const delta = std.time.timestamp() - timeStart;
    std.debug.print("Running Time: {} sec\n", .{delta});
}
const O = u32;
const S = struct { o: O };
fn in() S {
    return .{ .o = 3 };
}
fn st(state: *S) void {
    state.o +%= state.o;
    // state.o ^= state.p.int(O);
    // _ = state.p.int(O);
}
fn time() void {
    timeHelp(S, in, st);
}
fn timeHelp(
    comptime State: type,
    comptime init: fn () State,
    comptime step: fn (*State) void,
) void {
    // var output: Output = undefined
    var state: State = undefined;
    var best: f64 = 0;
    const endTime = std.time.nanoTimestamp() + 1_000_000_000;
    while (std.time.nanoTimestamp() < endTime) {
        state = init();
        var i: u32 = 0;
        const start = std.time.nanoTimestamp();
        while (i < 1 << 20) {
            defer i += 1;
            step(&state);
        }
        const new = @intToFloat(f64, i) / @intToFloat(f64, std.time.nanoTimestamp() - start);
        if (best < new) {
            best = new;
        }
    }
    std.debug.print("{d}, {}\n", .{ best, state });
}

// fn time() void {
//     var rng = prng.MCG32.init(69);
//     var dest: u8 = 0;
//     var i: u32 = 0;
//     const timeStart = lib.timeMicro();
//     while (true) {
//         const v = @bitCast(u8, rng.range(u8, @truncate(u8, i)));
//         // std.debug.print("{b:0>128}\n", .{@bitCast(u128, v)});
//         dest ^= v;
//         i +%= 1;
//         if (i == 0) {
//             break;
//         }
//     }
//     const timeEnd = lib.timeMicro();
//     std.debug.print("{d}, {}\n", .{ @intToFloat(f64, timeEnd - timeStart) / (1 << 32) * 1000, dest });
// }

// H1: 15, 0.26701706137000253
// a = (a ^ 61) ^ (a >> 16);
// a = a +% (a << 3);
// a = a ^ (a >> 4);
// a = a *% 0x27d4eb2d;
// a = a ^ (a >> 15);

// H2: 16 0.1867122507122507
// a = (a +% 0x7ed55d16) +% (a << 12);
// a = (a ^ 0xc761c23c) ^ (a >> 19);
// a = (a +% 0x165667b1) +% (a << 5);
// a = (a +% 0xd3a2646c) ^ (a << 9);
// a = (a +% 0xfd7046c5) +% (a << 3);
// a = (a ^ 0xb55a4f09) ^ (a >> 16);

// // H3: 16 0.22750618355391625
// a -%= (a << 6);
// a ^= (a >> 17);
// a -%= (a << 9);
// a ^= (a << 4);
// a -%= (a << 3);
// a ^= (a << 10);
// a ^= (a >> 15);

// // H4: 17 0.22889674743505783
// a +%= ~(a << 15);
// a ^= (a >> 10);
// a +%= (a << 3);
// a ^= (a >> 6);
// a +%= ~(a << 11);
// a ^= (a >> 16);

// // H5: 14 0.21360277042167447
// a = (a +% 0x479ab41d) +% (a << 8);
// a = (a ^ 0xe4aa10ce) ^ (a >> 5);
// a = (a +% 0x9942f0a6) -% (a << 14);
// a = (a ^ 0x5aedd67d) ^ (a >> 3);
// a = (a +% 0x17bea992) +% (a << 7);

// TODO: TEST EVERYTHING!
