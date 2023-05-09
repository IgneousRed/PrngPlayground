const std = @import("std");
const bits = @import("bits.zig");
const lib = @import("lib.zig");
const dev = @import("rng_dev.zig");

pub const Isaac64 = struct {
    state: std.rand.Isaac64,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.Isaac64.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Pcg = struct {
    state: std.rand.Pcg,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.Pcg.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const RomuTrio = struct {
    state: std.rand.RomuTrio,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.RomuTrio.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Sfc64 = struct {
    state: std.rand.Sfc64,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.Sfc64.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const SplitMix64 = struct {
    state: std.rand.SplitMix64,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.SplitMix64.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.next();
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Xoodoo = struct {
    state: std.rand.Xoodoo,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.Xoodoo.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Xoroshiro128 = struct {
    state: std.rand.Xoroshiro128,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.Xoroshiro128.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Xoshiro256 = struct {
    state: std.rand.Xoshiro256,

    pub fn init(seed: Seed) Self {
        return .{ .state = std.rand.Xoshiro256.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const RedMul = struct {
    pub usingnamespace RedBase;
    data: RedData,
    counter: RedBase.Out,

    pub fn init(seed: Seed, config: RedBase.Config) Self {
        const value = seed *% dev.oddPhiFraction(Seed);
        return .{
            .data = RedBase.init(config, bits.high(RedBase.Out, value)),
            .counter = bits.low(RedBase.Out, value),
        };
    }

    pub fn next(self: *Self) RedBase.Out {
        RedBase.algo(&self.data, self.counter);
        self.counter *%= dev.harmonicLCG(RedBase.Out);
        self.counter +%= dev.oddPhiFraction(RedBase.Out);
        return self.data.state; // TODO: Try output function, how will that affect 1kED
    }

    pub const bestKnown = RedBase.Config{ 1, 30, 1, 5 }; // round: 5, quality: 8.737424499861344
    pub const Seed = u128;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Red = struct {
    pub usingnamespace RedBase;
    data: RedData,
    counter: RedBase.Out,

    pub fn init(seed: Seed, config: RedBase.Config) Self {
        const value = seed *% dev.oddPhiFraction(Seed);
        return .{
            .data = RedBase.init(config, bits.high(RedBase.Out, value)),
            .counter = bits.low(RedBase.Out, value),
        };
    }

    pub fn next(self: *Self) RedBase.Out {
        defer self.counter +%= dev.oddPhiFraction(RedBase.Out);
        return RedBase.algo(&self.data, self.counter);
    }

    pub const bestKnown = RedBase.Config{ 3, 13, 1, 5 }; // round: 7, quality: 1.8438188170125223
    pub const Seed = u128;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Weyl32 = struct {
    state: Out,

    pub fn init(seed: Seed) Self {
        return .{ .state = seed };
    }

    pub fn next(self: *Self) Out {
        defer self.state +%= dev.oddPhiFraction(Out);
        return self.state;
    }

    pub const Seed = u32;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Weyl64 = struct {
    state: Out,

    pub fn init(seed: Seed) Self {
        return .{ .state = seed };
    }

    pub fn next(self: *Self) Out {
        defer self.state +%= dev.oddPhiFraction(Out);
        return self.state;
    }

    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Weyl128 = struct {
    state: Out,

    pub fn init(seed: Seed) Self {
        return .{ .state = seed };
    }

    pub fn next(self: *Self) Out {
        defer self.state +%= dev.oddPhiFraction(Out);
        return self.state;
    }

    pub const Seed = u128;
    pub const Out = u128;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const Weyl256 = struct {
    state: Out,

    pub fn init(seed: Seed) Self {
        return .{ .state = seed };
    }

    pub fn next(self: *Self) Out {
        defer self.state +%= dev.oddPhiFraction(Out);
        return self.state;
    }

    pub const Seed = u256;
    pub const Out = u256;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const SFC8 = struct {
    state: [4]Out,

    pub fn init(seed: Seed) Self {
        var value = seed *% dev.oddPhiFraction(Seed);
        var state: [4]Out = undefined;
        for (state) |*s| {
            s.* = @truncate(Out, value);
            value = value >> @bitSizeOf(Out);
        }
        return .{ .state = state };
    }

    pub fn next(self: *Self) Out {
        const result = self.state[0] +% self.state[1] +% self.state[3];
        self.state[0] = self.state[1] ^ (self.state[1] >> 1);
        self.state[1] = self.state[2] +% (self.state[2] << 2);
        self.state[2] = std.math.rotl(Out, self.state[2], 3) +% result;
        self.state[3] +%= dev.oddPhiFraction(Out);
        return result;
    }

    pub const Seed = u32;
    pub const Out = u8;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const JSF8 = struct {
    state: [4]Out,

    pub fn init(seed: Seed) Self {
        var value = seed *% dev.oddPhiFraction(Seed);
        var state: [4]Out = undefined;
        for (state) |*s| {
            s.* = @truncate(Out, value);
            value = value >> @bitSizeOf(Out);
        }
        return .{ .state = state };
    }

    pub fn next(self: *Self) Out {
        const temp = self.state[0] -% std.math.rotl(Out, self.state[1], 1);
        self.state[0] = self.state[1] ^ std.math.rotl(Out, self.state[2], 4);
        self.state[1] = self.state[2] +% self.state[3];
        self.state[2] = self.state[3] +% temp;
        self.state[3] = temp +% self.state[0];
        return self.state[3];
    }

    pub const Seed = u32;
    pub const Out = u8;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const NonDeter = struct {
    pub usingnamespace Base;
    data: Data,
    bias: u64,

    pub fn init(seed: Seed, config: Base.Config) Self {
        var self = .{
            .data = Base.init(config, seed *% dev.oddPhiFraction(Seed)),
            .bias = lib.nano64(),
        };
        runEntropy64(&self.data.state);
        return self;
    }

    pub fn next(self: *Self) Base.Out {
        Base.algo(&self.data, lib.nano64() - self.bias);
        return self.data.state;
    }

    pub const bestKnown = Base.Config{ 2, 16, 1, 0 };
    pub const Seed = u64;

    // -------------------------------- Internal --------------------------------

    const Data = RedData;
    const Base = RedBase;
    const Self = @This();
};

pub const NonDeterConfig2 = struct {
    pub usingnamespace Base;
    data: RedData,
    counter: Base.Out,

    pub fn init(seed: Seed, config: Base.Config) Self {
        const value = seed *% dev.oddPhiFraction(Seed);
        return .{
            .data = Base.init(config, bits.high(RedBase.Out, value)),
            .counter = bits.low(RedBase.Out, value),
        };
    }

    pub fn next(self: *Self) Base.Out {
        self.step();
        // const high = bits.high(32, self.data.state);
        self.step();
        self.step();
        self.step();
        // self.data.state = @intCast(u64, high) << 32 | bits.high(32, self.data.state);
        return self.data.state;
    }

    pub const bestKnown = Base.Config{ 2, 4, 1, 0 };
    pub const Seed = u128;

    // -------------------------------- Internal --------------------------------

    fn step(self: *Self) void {
        Base.algo(&self.data, self.counter - self.counter % 1000);
        self.counter += 50;
    }

    const Base = RedBase;
    const Self = @This();
};

pub const NonDeterConfig = struct {
    pub usingnamespace Base;
    data: RedData,
    counter: Base.Out,

    pub fn init(seed: Seed, config: Base.Config) Self {
        const value = seed *% dev.oddPhiFraction(Seed);
        return .{
            .data = Base.init(config, bits.high(RedBase.Out, value)),
            .counter = bits.low(RedBase.Out, value),
        };
    }

    pub fn next(self: *Self) Base.Out {
        Base.algo(&self.data, self.counter - self.counter % 1000);
        self.counter += 50;
        Base.algo(&self.data, self.counter - self.counter % 1000);
        self.counter += 50;
        Base.algo(&self.data, self.counter - self.counter % 1000);
        self.counter += 50;
        Base.algo(&self.data, self.counter - self.counter % 1000);
        self.counter += 50;
        Base.algo(&self.data, self.counter - self.counter % 1000);
        self.counter += 50;
        return self.data.state;
    }

    pub const bestKnown = Base.Config{ 2, 4, 1, 0 };
    pub const Seed = u128;

    // -------------------------------- Internal --------------------------------

    const Base = RedBase;
    const Self = @This();
};

const RedData = struct {
    usingnamespace RedBase;

    config: RedBase.Config,
    algo: RedBase.Algo,
    state: RedBase.Out,
};

const RedBase = struct {
    pub const configSize = Config{ 4, 63, 2, 6 };
    pub const configName = [_][]const u8{ "mix", "shift", "LCG", "algo" };
    pub const Algo = [3]usize;
    pub const Config = [4]usize;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    fn init(config: Config, state: Out) Data {
        for (config) |conf, c| if (conf >= configSize[c]) @panic("Invalid config");
        var algorithm: Algo = undefined;
        lib.indexPermutation(&algorithm, config[3]);
        var self = Data{
            .state = state,
            .config = config,
            .algo = algorithm,
        };
        return self;
    }

    fn algo(data: *Data, value: Out) Out {
        var result: Out = undefined;
        for (data.algo) |a| {
            switch (a) {
                0 => { // Mixin
                    const t = value;
                    switch (data.config[0]) {
                        0 => result = data.state ^ t,
                        1 => result = data.state +% t,
                        2 => result = data.state -% t,
                        3 => result = t -% data.state,
                        else => unreachable,
                    }
                    data.state = result;
                },
                1 => { // XorShift
                    data.state ^= data.state >> bits.ShiftCast(Out, data.config[1] + 1);
                },
                2 => { // Multiply
                    data.state *%= if (data.config[2] == 1)
                        dev.harmonicLCG(Out)
                    else
                        dev.harmonicMCG(Out);
                },
                else => unreachable,
            }
        }
        return result;
    }

    const Data = RedData;
    const Base = @This();
};

pub fn runEntropy64(state: *u64) void {
    const alloc = std.heap.page_allocator;
    const heap = alloc.create(u1) catch unreachable;
    alloc.destroy(heap);
    mixIn64(state, lib.nano64());
    mixIn64(state, @ptrToInt(&heap)); // MacOS: ~13bits of entropy
    mixIn64(state, @ptrToInt(heap)); // MacOS: ~13bits of entropy
    mixIn64(state, std.Thread.getCurrentId()); // MacOS: ~10bits of entropy
}

pub fn mixIn64(state: *u64, value: u64) void {
    state.* *%= dev.harmonicLCG(u64);
    state.* ^= state.* >> 31;
    state.* -%= value;
}

// TODO: Write and Read run results in files
