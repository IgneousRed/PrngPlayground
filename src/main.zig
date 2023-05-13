const std = @import("std");
const lib = @import("lib.zig");
const prng = @import("prng.zig");
const rng = @import("rng.zig");
const dev = @import("rng_dev.zig");
const bits = @import("bits.zig");
const tRNG = @import("testingRNG.zig");
const avelancheTest = @import("avelancheTest.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

fn avrDist(a: f64, b: f64) f64 {
    const avr = a + b;
    if (avr > 1) {
        return 1 - std.math.pow(f64, 2 - avr, 2) / 2;
    } else return std.math.pow(f64, avr, 2) / 2;
}
fn k1EDTest(comptime RNG: type, seed: RNG.Seed) void {
    var buckets: [RNG.Out]u64 = undefined;
    var cycleCount: u64 = 0;
    var r = RNG.init(seed);
    const initState = @bitCast(@bitSizeOf(RNG), r);
    while (@bitCast(@bitSizeOf(RNG), r) != initState) {
        buckets[r.next()] += 1;
        cycleCount += 1;
    }
    std.debug.print("{any}\n", .{buckets});
}
fn perm16(value: u16) u16 {
    var v = [2]u8{ bits.high(u8, value), bits.low(u8, value) };
    v[0] = std.math.rotl(u8, v[0], @popCount(v[1]));
    // v[0] = @bitReverse(v[1]) -% std.math.rotl(u8, v[0], v[1] >> 5);
    // v[1] = v[1] *% 33 +% 77;
    return @intCast(u16, v[1]) << 8 | v[0];
}
pub fn main() !void {
    // try permutationCheck(u16, perm16);
    // const Rng = rng.SFC;
    // avelancheTest.avelancheSummary(Rng, avelancheTest.avelancheTest(Rng, 12, 1 << 16));

    // try tRNG.configRNG(rng.Red, 20, 0, true, true, alloc);
    // try testing(rng.Test, 1);
    // try transitionTest();
    // mulXshSearch();
    // try permutationCheck(u16, perm16);
    // time();
}
fn testing(comptime RNG: type, seed: RNG.Seed) !void {
    var child = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin",
        // "-a",
        "-tf",
        "2",
        "-te",
        "1",
        "-tlmin",
        "10",
        "-tlmax",
        "99",
        // "-tlmaxonly",
        "-multithreaded",
    }, alloc);
    child.stdin_behavior = .Pipe;
    try child.spawn();
    const stdIn = child.stdin.?.writer();

    // var random = RNG.init(seed, RNG.bestKnown);
    var random = RNG.init(seed);
    var buf: [1 << 16]RNG.Out = undefined;
    while (true) {
        for (buf) |*b| {
            b.* = random.next();
        }
        try stdIn.writeAll(std.mem.asBytes(&buf));
    }
}
fn transitionTest(comptime T: type, comptime f: fn (T) T) !void {
    const timeStart = std.time.timestamp();
    var bitsSet = std.StaticBitSet(1 << @bitSizeOf(T)).initEmpty();
    var i: T = 0;
    if (blk: while (true) {
        const index = f(i);
        if (bitsSet.isSet(index)) {
            break :blk false;
        }
        bitsSet.set(index);
        i +%= 1;
        if (i == 0) {
            break :blk true;
        }
    }) {
        std.debug.print("The function is a permutation!\n", .{});
    } else {
        std.debug.print("The function is NOT a permutation\n", .{});
    }
    const delta = std.time.timestamp() - timeStart;
    std.debug.print("Running Time: {} sec\n", .{delta});
}
fn mulXshSearch() void {
    const bitSize = 12;
    const T = bits.U(bitSize);
    var goodCount: usize = 0;
    var mul: T = 5;
    while (true) {
        var add: T = 1;
        while (true) {
            var good = true;
            var set = std.bit_set.ArrayBitSet(usize, 1 << bitSize).initEmpty();
            var state: T = 1;
            var i: usize = 0;
            while (i < 1 << bitSize) {
                var new = state *% mul;
                new +%= add;
                state = new ^ new >> bitSize / 2;
                if (set.isSet(state)) {
                    good = false;
                    break;
                }
                set.set(state);
                i += 1;
            }
            if (good) {
                goodCount += 1;
                // std.debug.print("{d:0>4}\n", .{mul});
                // std.debug.print("{d:0>4} {d:0>4}\n", .{ mul, add });
            }
            add +%= 2;
            if (add == 1) {
                break;
            }
        }
        mul +%= 8;
        if (mul == 5) {
            break;
        }
    }
    const total = (1 << bitSize) * (1 << bitSize);
    const proc = @intToFloat(f64, goodCount) / @intToFloat(f64, total);
    std.debug.print("{} out of {}, or {d}%\n", .{ goodCount, total, proc });
}
fn permutationCheck(comptime T: type, comptime f: fn (T) T) !void {
    const timeStart = std.time.timestamp();
    var bitsSet = std.StaticBitSet(1 << @bitSizeOf(T)).initEmpty();
    var i: T = 0;
    if (blk: while (true) {
        const index = f(i);
        if (bitsSet.isSet(index)) {
            break :blk false;
        }
        bitsSet.set(index);
        i +%= 1;
        if (i == 0) {
            break :blk true;
        }
    }) {
        std.debug.print("The function is a permutation!\n", .{});
    } else {
        std.debug.print("The function is NOT a permutation\n", .{});
    }
    const delta = std.time.timestamp() - timeStart;
    std.debug.print("Running Time: {} sec\n", .{delta});
}
const S = u64;
// const S = std.rand.DefaultPrng;
const O = u32;
fn in() S {
    return 1;
    // return std.rand.DefaultPrng.init(0);
}
fn stepFn(s: *S) O {
    s.* *%= 0xd1342543de82ef95;
    s.* +%= 0xf1357aea2e62a9c5;
    s.* ^= s.* >> 32;
    return @truncate(u32, s.*);
    // return s.i.random().int(u32);
}
fn time() void {
    timeHelp(O, S, in, stepFn);
}
fn timeHelp(
    comptime Out: type,
    comptime State: type,
    comptime init: fn () State,
    comptime step: fn (*State) Out,
) void {
    var out: Out = undefined;
    var state: State = undefined;
    var best: f64 = 0;
    const endTime = std.time.nanoTimestamp() + 1_000_000_000;
    while (std.time.nanoTimestamp() < endTime) {
        state = init();
        var i: u32 = 0;
        const start = std.time.nanoTimestamp();
        while (i < 1 << 20) {
            defer i += 1;
            out = step(&state);
        }
        const new = @intToFloat(f64, i) / @intToFloat(f64, std.time.nanoTimestamp() - start);
        if (best < new) {
            best = new;
        }
    }
    std.debug.print("{d}, {}\n", .{ best, out });
}

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
// TODO: Try to const everything
// TODO: Delete unused imports
// TODO: Disable optimizations `asm volatile("" ::: "memory")`
