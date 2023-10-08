const std = @import("std");
// const lib = @import("lib.zig");
// const prng = @import("prng.zig");
const rng = @import("rng.zig");
const dev = @import("rngDev.zig");
const bits = @import("bits.zig");
// const tRNG = @import("testingRNG.zig");
const qt = @import("quickTest.zig");
const algo = @import("algo.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

fn perm32(value: u32) u32 {
    var v = [4]u8{ bits.low(u8, value), bits.low(u8, value >> 8), bits.low(u8, value >> 16), bits.low(u8, value >> 24) };
    const mul = bits.multiplyFull(v[0], v[3]);
    const a = v[0];
    v[0] = v[1] +% mul.low;
    v[1] = v[2] +% v[3];
    v[2] = a +% mul.high;
    return bits.concat(bits.concat(v[3], v[2]), bits.concat(v[1], v[0]));
}

fn perm24(value: u24) u24 {
    var v = [3]u8{ bits.low(u8, value), bits.low(u8, value >> 8), bits.low(u8, value >> 16) };
    const mul = bits.multiplyFull(v[0], 0);
    const a = v[0];
    v[0] = v[1] +% mul.low;
    v[1] = v[2] +% 0;
    v[2] = a +% mul.high;
    return bits.concat(v[2], bits.concat(v[1], v[0]));
}

const Test = struct {
    state: [4]Out,
    pub fn init(seed: Seed) Self {
        var self: Self = .{ .state = .{ seed, ~seed, -%seed, ~-%seed } };
        for (0..10) |_| _ = self.next();
        return self;
    }
    pub fn next(self: *Self) Out {
        var a = self.state[1] -% self.state[0];
        self.state[0] = self.state[1] +% self.state[2];
        self.state[1] = a -% self.state[2];
        self.state[2] = self.state[3] -% bits.ror(a, 15);
        self.state[3] +%= dev.oddPhiFraction(Out);
        return self.state[0];
    }
    pub const Out = u16;
    pub const Seed = Out;

    // -------------------------------- Internal --------------------------------
    const Self = @This();
};

pub fn main() !void {
    // try diagnose(rng.WYR64);
    // try diagnosePermutation(rng.WYR64);
    // uniformCheck(rng.WYR64);

    // timingRng(rng.MWC3(u64, true));
    // try testing(rng.MWC8, 0, "1", "0");
    try testing(rng.WYR(u32), 0, "2", "1");
    // try permutationCheck(u24, perm24);
    // try permutationCheck(u32, perm32);

    // const data = try qt.quickTestRaw(rng.MWC64, 8, 1 << 16, alloc);
    // for (data, 1..) |d, i| {
    //     std.debug.print("{d:2} {d}\n", .{ i, d });
    // }
    // std.debug.print("{d}\n", .{try qt.quickTest(rng.MWC64, 8, 1 << 16, alloc)});
}

// Name         Speed(ns/op)
// WYR(64)      0.3814697265625
// MWC3(64)     0.5645751953125(0.579833984375)
// SFC(64)      0.885009765625
// JSF(64)      0.9002685546875
// Xoshiro256   0.9918212890625
// Xoroshiro128 1.15966796875
// GJR(64)      1.5411376953125 // Test
fn timingRng(comptime Prng: type) void {
    var time = ~@as(u64, 0);
    var sum: usize = 0;
    var buf: [1 << 16]Prng.Out = .{0} ** (1 << 16);
    var prng = Prng.init(0);
    for (0..1 << 16) |_| {
        var temp = std.time.nanoTimestamp();
        for (0..1 << 16) |i| {
            buf[i] = prng.next();
        }
        time = @min(time, @as(u64, @intCast(std.time.nanoTimestamp() - temp)));
        for (buf) |v| {
            sum +%= v;
        }
    }
    std.debug.print("{d}, {d}\n", .{ @as(f64, @floatFromInt(time)) / (1 << 16), sum });
}
fn diagnoseUniformity(comptime Prng: type) void { // check
    var r: Prng = undefined;
    const Word = @TypeOf(r.state[0]);
    var buckets: [1 << @bitSizeOf(Prng.Out)]usize = .{0} ** (1 << 8);
    for (0..1 << (r.state.len * @bitSizeOf(Word))) |i| {
        var val = i;
        for (&r.state) |*state| {
            state.* = bits.low(Word, val);
            val >>= 8;
        }
        buckets[r.next()] += 1;
    }
    for (buckets[0..]) |b| {
        if (buckets[0] != b) {
            std.debug.print("Function does NOT have uniform output!\n", .{});
            return;
        }
    }
    std.debug.print("Function DOES have uniform output!\n", .{});
}
fn diagnosePermutation(comptime Prng: type) !void {
    _ = Prng;
    // var r: Prng = undefined;
    // const Word = @TypeOf(r.state[0]);
    // var bitsSet = try std.DynamicBitSet.initEmpty(alloc, 1 << @bitSizeOf(Prng));
    // for (0..1 << (r.state.len * @bitSizeOf(@TypeOf(r.state[0])))) |i| {
    //     const index = f(@as(T, @intCast(i)));
    //     if (bitsSet.isSet(index)) {
    //         std.debug.print("The function is NOT a permutation\n", .{});
    //         return;
    //     }
    //     bitsSet.set(index);
    // }
    // std.debug.print("The function is a permutation!\n", .{});
}
fn permutationCheck(comptime T: type, comptime f: fn (T) T) !void {
    var bitsSet = try std.DynamicBitSet.initEmpty(alloc, 1 << @bitSizeOf(T));
    for (0..1 << @bitSizeOf(T)) |i| {
        const index = f(@as(T, @intCast(i)));
        if (bitsSet.isSet(index)) {
            std.debug.print("The function is NOT a permutation\n", .{});
            return;
        }
        bitsSet.set(index);
    }
    std.debug.print("The function is a permutation!\n", .{});
}
fn testing(comptime Prng: type, seed: Prng.Seed, fold: []const u8, expanded: []const u8) !void {
    var child = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin",
        // "-a",
        "-tf",
        fold,
        "-te",
        expanded,
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

    var random = Prng.init(seed);
    var buf: [1 << 16]Prng.Out = undefined;
    while (true) {
        for (&buf) |*b| {
            b.* = random.next();
        }
        try stdIn.writeAll(std.mem.asBytes(&buf));
    }
}
