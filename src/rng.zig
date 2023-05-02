const std = @import("std");
const rand = std.rand;
const Random = rand.Random;
const bits = @import("bits.zig");
const lib = @import("lib.zig");
const dev = @import("rng_dev.zig");

pub const Isaac64 = struct {
    state: rand.Isaac64,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.Isaac64.init(seed) };
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
    state: rand.Pcg,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.Pcg.init(seed) };
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
    state: rand.RomuTrio,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.RomuTrio.init(seed) };
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
    state: rand.Sfc64,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.Sfc64.init(seed) };
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
    state: rand.SplitMix64,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.SplitMix64.init(seed) };
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
    state: rand.Xoodoo,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.Xoodoo.init(seed) };
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
    state: rand.Xoroshiro128,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.Xoroshiro128.init(seed) };
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
    state: rand.Xoshiro256,

    pub fn init(seed: Seed) Self {
        return .{ .state = rand.Xoshiro256.init(seed) };
    }

    pub fn next(self: *Self) Out {
        return self.state.random().int(Out);
    }

    pub const Seed = u64;
    pub const Out = u64;

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
        defer self.counter +%= dev.oddPhiFraction(RedBase.Out); // 19.48789692645912, 19.468798919734887
        RedBase.algo(&self.data, self.counter);
        return self.data.state;
    }

    pub const bestKnown = RedBase.Config{ 1, 48, 1, 5 }; // 5, 20, 12.522809546723856
    pub const Seed = u128;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const RedRev = struct {
    config: Config,
    algo: Algo,
    state: Out,
    counter: Out,

    pub fn init(seed: Seed, config: Config) Self {
        for (config) |conf, c| if (conf >= configSize[c]) @panic("Invalid config");
        const value = seed *% dev.oddPhiFraction(Seed);
        var algorithm: Algo = undefined;
        lib.indexPermutation(&algorithm, config[2]);
        return .{
            .state = bits.high(Out, value),
            .config = config,
            .algo = algorithm,
            .counter = bits.low(Out, value),
        };
    }

    pub fn next(self: *Self) Out {
        defer self.counter +%= dev.oddPhiFraction(Out);

        for (self.algo) |a| {
            switch (a) {
                0 => { // Mixin
                    const t = self.counter;
                    switch (self.config[0]) {
                        0 => self.state ^= t,
                        1 => self.state +%= t,
                        2 => self.state -%= t,
                        3 => self.state = t -% self.state,
                        else => unreachable,
                    }
                },
                1 => { // Multiply
                    self.state *%= if (self.config[1] == 1)
                        dev.harmonicLCG(Out)
                    else
                        dev.harmonicMCG(Out);
                },
                2 => { // Reverse
                    self.state = @bitReverse(self.state);
                },
                else => unreachable,
            }
        }
        return self.state;
    }

    pub const bestKnown = Config{ 1, 1, 5 }; // 4, 20, 17.67381136557499
    pub const configSize = Config{ 4, 2, 6 };
    pub const configName = [_][]const u8{ "mix", "LCG", "algo" };
    pub const Algo = [3]usize;
    pub const Config = [3]usize;
    pub const Seed = u128;
    pub const Out = u64;

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

    fn algo(data: *Data, value: Out) void {
        for (data.algo) |a| {
            switch (a) {
                0 => { // Mixin
                    const t = value;
                    switch (data.config[0]) {
                        0 => data.state ^= t,
                        1 => data.state +%= t,
                        2 => data.state -%= t,
                        3 => data.state = t -% data.state,
                        else => unreachable,
                    }
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
    }

    const Data = RedData;
    const Base = @This();
};

pub fn runEntropy64(state: *u64) void {
    const alloc = std.heap.page_allocator;
    const heap = alloc.create(u1) catch unreachable;
    alloc.destroy(heap);
    mix64(state, lib.nano64());
    mix64(state, @ptrToInt(&heap)); // MacOS: ~13bits of entropy
    mix64(state, @ptrToInt(heap)); // MacOS: ~13bits of entropy
    mix64(state, std.Thread.getCurrentId()); // MacOS: ~10bits of entropy
}

pub fn mix64(state: *u64, value: u64) void {
    state.* ^= value;
    state.* ^= state.* >> 48;
    state.* *%= dev.harmonicMCG(u64);
}

// TODO: Write and Read run results in files
