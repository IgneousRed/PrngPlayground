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

fn MyRNG() type {
    return struct {
        state: State,

        pub fn init(asd: State, config: Config) Self {
            _ = config;
            return Self{ .state = asd *% dev.oddPhiFraction(State) };
        }

        pub fn gen(self: *Self) Out {
            self.state *%= dev.harmonic64LCG64;
            self.state +%= dev.golden64;
            return @truncate(Out, self.state >> 32);
        }

        pub const Config = struct {};

        pub const State = u64;
        pub const Out = u32;

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}
const EntropyRNG = struct {
    state: State,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = try Self{ .state = Self.time() };
        const p = allocator.create(u1);
        allocator.destroy(p);
        self.mix(@truncate(State, @ptrToInt(&p)));
        self.mix(@truncate(State, @ptrToInt(p)));
        return self;
    }

    pub fn gen(self: *Self) Out {
        self.mix(Self.time());
        return @intCast(Out, self.state >> @bitSizeOf(State) - @bitSizeOf(Out));
    }

    pub const State = u64;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    fn mix(self: *Self, value: State) void {
        self.state = value -% self.state;
        self.state ^= self.state >> 47;
        self.state *%= dev.harmonicMCG(State);
    }

    fn time() State {
        return @truncate(State, @intCast(u128, std.time.nanoTimestamp()));
    }

    const Self = @This();
};
const NonDeter = struct {
    state: State,
    config: Config,

    pub fn init(seed: State, config: Config) Self {
        var self = Self{ .state = seed *% dev.oddPhiFraction(State), .config = config };
        const heap = alloc.create(u1) catch unreachable;
        alloc.destroy(heap);
        self.mix(Self.time());
        self.mix(@truncate(State, @ptrToInt(heap)));
        self.mix(@truncate(State, @ptrToInt(&heap)));
        return self;
    }

    pub fn gen(self: *Self) Out {
        self.mix(Self.time());
        return @intCast(Out, self.state >> @bitSizeOf(State) - @bitSizeOf(Out));
    }

    pub const Config = struct {
        mix: usize,
        shift: usize,
        lcg: bool,
    };

    pub const State = u64;

    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    fn mix(self: *Self, value: State) void {
        const t = value;
        switch (self.config.mix) {
            0 => self.state ^= t,
            1 => self.state +%= t,
            2 => self.state -%= t,
            3 => self.state = t -% self.state,
            else => @panic("Mix must be < 4"),
        }
        self.state ^= self.state >> math.log2_int(State, @intCast(State, self.config.shift));
        self.state *%= if (self.config.lcg) dev.harmonicLCG(State) else dev.harmonicMCG(State);
    }

    fn time() State {
        return @truncate(State, @intCast(u128, std.time.nanoTimestamp()));
    }

    const Self = @This();
};

pub fn main() !void {
    try autoTest.testRNG(MyRNG(), 20, 2 << (1 << 5), 1 << 2, .{}, alloc);
    // const config = NonDeter.Config{
    //     .mix = 3,
    //     .shift = 47,
    //     .lcg = false,
    // };
    // try testing(NonDeter, config);
    // try autoConfig();
    // try transitionTest();
    // mulXshSearch();
    // try permutationCheck(u16, perm16);
    // time();
}
fn autoConfig() !void {
    var config = NonDeter.Config{
        .mix = 3,
        .lcg = false,
        .shift = 47,
    };
    var round: usize = 0;
    while (true) {
        defer round += 1;
        std.debug.print("Round {}\n", .{round});
        var j: usize = 0;
        while (j < 2) {
            defer j += 1;
            // Mix
            var best = autoTest.Score{ .order = 0, .fault = math.inf_f64 };
            var bestI: usize = undefined;
            var i: usize = 0;
            while (i < 4) {
                defer i += 1;
                config.mix = i;
                const result = try autoTest.testRNG(NonDeter, 10, 2 << (1 << 5), config, alloc);
                std.debug.print("  Mix {}, Score {}\n", .{ config.mix, result });
                if (best.worseThan(result)) {
                    best = result;
                    bestI = i;
                }
            }
            config.mix = bestI;
            std.debug.print("New Mix {}, Score {}\n", .{ config.mix, best });
            // Lcg
            config.lcg = false;
            const resultF = try autoTest.testRNG(NonDeter, 10, 2 << (1 << 5), config, alloc);
            std.debug.print("  Lcg false, Score {}\n", .{resultF});
            config.lcg = true;
            const resultT = try autoTest.testRNG(NonDeter, 10, 2 << (1 << 5), config, alloc);
            std.debug.print("  Lcg true, Score {}\n", .{resultT});
            if (resultF.worseThan(resultT)) {
                config.lcg = true;
                best = resultT;
            } else {
                config.lcg = false;
                best = resultF;
            }
            std.debug.print("New Lcg {}, Score {}\n", .{ config.lcg, best });
        }
        // Shift
        var best = autoTest.Score{ .order = 0, .fault = math.inf_f64 };
        var bestI: usize = undefined;
        var i: usize = 2;
        while (i < 64) {
            defer i += 1;
            config.shift = i;
            const result = try autoTest.testRNG(NonDeter, 10, 2 << (1 << 5), config, alloc);
            std.debug.print("  Shift {}, Score {}\n", .{ config.shift, result });
            if (best.worseThan(result)) {
                best = result;
                bestI = i;
            }
        }
        config.shift = bestI;
        std.debug.print("Final Mix {}, Lcg {}, Shift {}, Score {}\n", .{ config.mix, config.lcg, config.shift, best });
    }
}
fn testing(comptime RNG: type, config: RNG.Config) !void {
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

    var rng = RNG.init(0, config);
    var buf: [1 << 16]RNG.Out = undefined;
    while (true) {
        for (buf) |*b| {
            b.* = rng.gen();
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
