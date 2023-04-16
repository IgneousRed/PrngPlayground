const std = @import("std");
const lib = @import("lib.zig");
const prng = @import("prng.zig");
const dev = @import("prng_dev.zig");
const bits = @import("bits.zig");
const autoTest = @import("autoTest.zig");
const rand = std.rand;
const math = std.math;
const builtin = @import("builtin");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

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
fn avrDist(a: f64, b: f64) f64 {
    const avr = a + b;
    if (avr > 1) {
        return 1 - math.pow(f64, 2 - avr, 2) / 2;
    } else return math.pow(f64, avr, 2) / 2;
}

fn MyRng(comptime outBits: comptime_int) type {
    return struct {
        state: State,

        pub fn init(asd: State) Self {
            return Self{ .state = asd *% dev.oddPhiFraction(State) };
        }

        pub fn gen(self: *Self) Out {
            self.state *%= dev.harmonic64LCG64;
            self.state +%= dev.golden64;
            return bits.highBits(outBits, self.state);
        }

        pub const State = bits.U(outBits * 2);
        pub const Out = bits.U(outBits);

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}

// timeMix: [0,4)
// add: [0,4)
// addMix: [0,4)
// shift: [0,32)
fn NonDeter(
    comptime timeMix: usize,
    comptime mulLCG: bool,
    comptime add: usize,
    comptime addMix: usize,
    comptime shift: u6,
) type {
    return struct {
        state: Out,

        pub fn init(seed: Out) Self {
            return Self{ .state = seed *% dev.oddPhiFraction(Out) };
        }

        pub fn gen(self: *Self) Out {
            const t = @truncate(Out, @divTrunc(@intCast(u128, std.time.nanoTimestamp()), 1000));
            switch (timeMix) {
                0 => self.state ^= t,
                1 => self.state +%= t,
                2 => self.state -%= t,
                3 => self.state = t -% self.state,
                else => @compileError("Nop"),
            }
            self.state *%= if (mulLCG) dev.harmonic64LCG64 else dev.harmonic64MCG64;
            const val = switch (add) {
                0 => 0,
                1 => dev.harmonic64LCG64,
                2 => dev.harmonic64MCG64,
                3 => dev.oddPhiFraction(Out),
                else => @compileError("Nop"),
            };
            switch (addMix) {
                0 => self.state ^= val,
                1 => self.state +%= val,
                2 => self.state -%= val,
                3 => self.state = val -% self.state,
                else => @compileError("Nop"),
            }
            if (shift > 0) self.state ^= self.state >> shift;
            return self.state;
        }

        pub const Out = u64;

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}

fn score(comptime T: type, comptime orders: u6, comptime runs: usize) !autoTest.Score {
    const results = try autoTest.testPRNG(T, orders, runs);
    const result = try autoTest.collapseRuns(orders, runs, results);
    const summary = autoTest.summarize(orders, result);
    const verdict = autoTest.verdict(orders, summary, true);
    return autoTest.score(orders, verdict, std.math.inf_f64);
}

pub fn main() !void {
    const timeMix = 1; // 2
    const mulLCG = true; // false
    const add = 3; // 1
    const addMix = 0; // 1
    const shift = 21; // 21

    std.debug.print("timeMix:\n", .{});
    _ = timeMix;
    comptime var i: comptime_int = 0;
    inline while (i < 4) {
        const result = try autoTest.testRNG(NonDeter(i, mulLCG, add, addMix, shift), 99, 1 << (1 << 5), alloc);
        std.debug.print("{}: {any}\n", .{ i, result });
        i += 1;
    }

    // std.debug.print("mulLCG:\n", .{});
    // _ = mulLCG;
    // var result = try autoTest.testRNG(NonDeter(timeMix, false, add, addMix, shift), 99, 1 << (1 << 5), alloc);
    // std.debug.print("false: {any}\n", .{result});
    // result = try autoTest.testRNG(NonDeter(timeMix, true, add, addMix, shift), 99, 1 << (1 << 5), alloc);
    // std.debug.print("true: {any}\n", .{result});

    // std.debug.print("add:\n", .{});
    // _ = add;
    // comptime var i: comptime_int = 1;
    // inline while (i < 4) {
    //     const result = try autoTest.testRNG(NonDeter(timeMix, mulLCG, i, addMix, shift), 99, 1 << (1 << 5), alloc);
    //     std.debug.print("{}: {any}\n", .{ i, result });
    //     i += 1;
    // }

    // std.debug.print("addMix:\n", .{});
    // _ = addMix;
    // comptime var i: comptime_int = 0;
    // inline while (i < 4) {
    //     const result = try autoTest.testRNG(NonDeter(timeMix, mulLCG, add, i, shift), 99, 1 << (1 << 5), alloc);
    //     std.debug.print("{}: {any}\n", .{ i, result });
    //     i += 1;
    // }

    // std.debug.print("shift:\n", .{});
    // _ = shift;
    // comptime var i: comptime_int = 1;
    // inline while (i < 64) {
    //     const result = try autoTest.testRNG(NonDeter(timeMix, mulLCG, add, addMix, i), 99, 1 << (1 << 5), alloc);
    //     std.debug.print("{}: {any}\n", .{ i, result });
    //     i += 1;
    // }

    // try testing();
    // try transitionTest();
    // mulXshSearch();
    // try permutationCheck(u16, perm16);
    // time();
}
fn testing() !void {
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

    const T = u32;
    var state: T = 3;
    var buf = [1]u16{0} ** (1 << 16);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            defer i += 1;

            // defer state += 1;
            // var value: T = state;

            // value *%= dev.harmonic64MCG64;
            // value ^= value >> 32;
            // value *%= dev.harmonic64MCG64;
            // value ^= value >> 32;
            // value *%= dev.harmonic64MCG64;
            // value ^= value >> 32;
            // buf[i] = value;

            state *%= dev.harmonic32LCG32;
            state +%= dev.harmonic32MCG32;

            // state = @bitReverse(state);
            state ^= state >> 23;

            // buf[i] = @truncate(u16, state);
            buf[i] = @intCast(u16, state >> 16);
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
