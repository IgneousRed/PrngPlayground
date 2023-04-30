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

pub const MyRng = struct {
    state: Out,
    counter: Out,
    config: Config,

    pub fn init(seed: Seed, config: Config) Self {
        const phi = seed *% dev.oddPhiFraction(Seed);
        return .{ .state = bits.highBits(64, phi), .counter = bits.low(64, phi), .config = config };
    }

    pub fn next(self: *Self) Out {
        defer self.counter +%= dev.oddPhiFraction(Out);

        self.state +%= self.counter;
        self.state ^= self.state >> 27;
        self.state *%= dev.harmonicLCG(Out);

        return self.state;
    }

    pub const bestKnown = Config{ 1, 3, 41, 1 };
    pub const configSize = Config{ 6, 4, 63, 2 };
    pub const configName = [_][]const u8{ "algo", "mix", "shift", "LCG" };
    pub const Config = [4]usize;
    pub const Seed = u128;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const MyRngSimple = struct {
    state: Out,

    pub fn init(seed: Seed) Self {
        return .{ .state = seed *% dev.oddPhiFraction(Out) };
    }

    pub fn next(self: *Self) Out {
        self.state *%= dev.harmonicLCG(Out);
        self.state ^= self.state >> 2;
        self.state +%= dev.harmonicMCG(Out);

        return self.state;
    }

    pub const Seed = Out;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const MyRngConfig = struct {
    pub usingnamespace Base;

    data: Data,
    counter: Base.Seed = 0,

    pub fn init(seed: Base.Seed, config: Base.Config) Self {
        return .{ .data = Base.init(seed, config) };
    }

    pub fn next(self: *Self) Base.Out {
        defer self.counter += 1000;
        return Base.algo(&self.data, self.counter);
    }

    // -------------------------------- Internal --------------------------------

    const Data = MyRngData;
    const Base = MyRngBase;
    const Self = @This();
};

// pub const MyRng = struct {
//     pub usingnamespace Base;

//     data: Data,

//     pub fn init(seed: Base.Seed, config: Base.Config) Self {
//         var self = .{ .data = Base.init(seed, config) };
//         runEntropy64(&self.data.state);
//         return self;
//     }

//     pub fn next(self: *Self) Base.Out {
//         return Base.algo(&self.data, time64());
//     }

//     // -------------------------------- Internal --------------------------------

//     const Data = MyRngData;
//     const Base = MyRngBase;
//     const Self = @This();
// };

pub const RngCounter = struct {
    usingnamespace MyRngBase;
    data: MyRngData,
    counter: Base = 0,

    pub fn init(seed: Base, config: Base.Config) Self {
        // for (config) |conf, c| {
        //     if (conf >= configSize[c]) @panic("Invalid config");
        // }
        return Self{ .state = seed *% dev.oddPhiFraction(Base), .config = config };
    }

    pub fn next(self: *Self) Base.Out {
        defer self.counter += 1000;
        MyRngBase.algo(self.data, self.counter);
        return self.state;
    }

    pub const bestKnown = Base.Config{ 0, 1, 6, 1 };
    // -------------------------------- Internal --------------------------------

    const Base = MyRngBase;
    const Self = @This();
};

const MyRngData = struct {
    usingnamespace MyRngBase;

    state: MyRngBase.Seed,
    config: MyRngBase.Config,
    algo: MyRngBase.Algo,
};

const MyRngBase = struct {
    pub const configSize = Config{ 4, 63, 2, 6 };
    pub const configName = [_][]const u8{ "mix", "shift", "LCG", "algo" };
    pub const Algo = [3]usize;
    pub const Config = [4]usize;
    pub const Seed = u64;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    fn init(seed: Seed, config: Config) Data {
        _ = seed;
        for (config) |conf, c| if (conf >= configSize[c]) @panic("Invalid config");
        const algorithm: Algo = undefined;
        lib.indexPermutation(algorithm, config[3]);
        var self = Data{
            // .state = seed *% dev.oddPhiFraction(Seed),
            .config = config,
            .algo = algorithm,
        };
        return self;
    }

    fn algo(data: *Data, value: Seed) void {
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
                    data.state ^= data.state >> bits.ShiftCast(Seed, data.config[1] + 1);
                },
                2 => { // Multiply
                    data.state *%= if (data.config[2] == 1)
                        dev.harmonicLCG(Seed)
                    else
                        dev.harmonicMCG(Seed);
                },
            }
        }
    }

    const Data = MyRngData;
    const Base = @This();
};

pub fn runEntropy64(state: *u64) void {
    const alloc = std.heap.page_allocator;
    const heap = alloc.create(u1) catch unreachable;
    alloc.destroy(heap);
    mix64(state, time64());
    mix64(state, @ptrToInt(&heap)); // MacOS: ~13bits of entropy
    mix64(state, @ptrToInt(heap)); // MacOS: ~13bits of entropy
    mix64(state, std.Thread.getCurrentId()); // MacOS: ~10bits of entropy
}

pub fn mix64(state: *u64, value: u64) void {
    state.* ^= value;
    state.* ^= state.* >> 48;
    state.* *%= dev.harmonicMCG(u64);
}

pub fn time64() u64 {
    return @truncate(u64, @intCast(u128, std.time.nanoTimestamp()));
}

// TODO: Write and Read run results in files
