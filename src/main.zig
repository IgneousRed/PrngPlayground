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
    var q = v[0] +% v[1];
    var w = v[1] +% v[0];
    v[0] = q;
    v[1] = w;
    var result = bits.concat(u16, v[0], v[1]);
    return result;
}
fn perm32(value: u32) u32 {
    var v = [4]u8{ bits.high(u8, value), bits.low(u8, bits.high(u16, value)), bits.high(u8, bits.low(u16, value)), bits.low(u8, value) };
    v[0] -%= v[1];
    v[2] -%= v[3];

    v[1] -%= v[0];
    v[3] -%= v[2];
    var result = bits.concat(u32, bits.concat(u16, v[0], v[1]), bits.concat(u16, v[2], v[3]));
    return result;
}
fn mult(a: u8, b: u8) struct { high: u8, low: u8 } {
    var temp = @intCast(u16, a) * b;
    return .{ .high = bits.high(u8, temp), .low = bits.low(u8, temp) };
}
pub fn main() !void {
    // std.debug.print("{x}", .{dev.oddPhiFraction(u128)});
    // var i: usize = 0;
    // var s: u16 = 0;
    // while (true) {
    //     s *%= 4 * 4 + 1;
    //     s +%= 0b0001;
    //     if (s == 0) break;
    //     i += 1;
    // }
    // std.debug.print("{}", .{i});

    // try permutationCheck(u32, perm32);
    // const Rng = rng.SFC;
    // avelancheTest.avelancheSummary(Rng, avelancheTest.avelancheTest(Rng, 12, 1 << 16));

    // try tRNG.configRNG(rng.Red, 20, 0, true, true, alloc);
    // try testing(rng.SFC8, 0);
    // try testing(rng.MSWS, 0);
    // try testing(rng.Test, 0);
    // time();

    // try transitionTest();
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
    var bitsSet = try alloc.create(std.StaticBitSet(1 << @bitSizeOf(T)));
    bitsSet.initEmpty();
    var i: T = 0;
    if (blk: while (true) {
        i = f(i);
        if (bitsSet.isSet(i)) break :blk false;
        bitsSet.set(i);
        if (i == 0) break :blk true;
    }) {
        std.debug.print("The function has 1 cycle!\n", .{});
    } else {
        std.debug.print("The function has more cycles\n", .{});
    }
    const delta = std.time.timestamp() - timeStart;
    std.debug.print("Running Time: {} sec\n", .{delta});
}
fn permutationCheck(comptime T: type, comptime f: fn (T) T) !void {
    const timeStart = std.time.timestamp();
    var bitsSet = try std.DynamicBitSet.initEmpty(alloc, 1 << @bitSizeOf(T));
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
