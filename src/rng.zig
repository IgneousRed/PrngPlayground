const std = @import("std");
const rand = std.rand;
const Random = rand.Random;
const bits = @import("bits.zig");
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

    pub fn init(seed: Seed) Self {
        const phi = seed *% dev.oddPhiFraction(Seed);
        return .{ .state = bits.highBits(64, phi), .counter = bits.low(64, phi) };
    }

    pub fn next(self: *Self) Out {
        defer self.counter +%= dev.oddPhiFraction(Out);

        self.state +%= self.counter;
        self.state ^= self.state >> 27;
        self.state *%= dev.harmonicLCG(Out);

        return self.state;
    }

    pub const Seed = bits.U(@bitSizeOf(Out) * 2);
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

pub const NonDeter32Config = struct {
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

    const Data = NonDeter32Data;
    const Base = NonDeter32Base;
    const Self = @This();
};

pub const NonDeter32 = struct {
    pub usingnamespace Base;

    data: Data,

    pub fn init(seed: Base.Seed, config: Base.Config) Self {
        var self = .{ .data = Base.init(seed, config) };
        runEntropy64(&self.data.state);
        return self;
    }

    pub fn next(self: *Self) Base.Out {
        return Base.algo(&self.data, time64());
    }

    // -------------------------------- Internal --------------------------------

    const Data = NonDeter32Data;
    const Base = NonDeter32Base;
    const Self = @This();
};

const NonDeter32Data = struct {
    usingnamespace NonDeter32Base;

    state: NonDeter32Base.Seed,
    config: NonDeter32Base.Config,
};

const NonDeter32Base = struct {
    pub const bestKnown = Config{ 1, 3, 41, 1 }; // round: 4, order: 20, quality: 13.378188881204963
    pub const configSize = Config{ 6, 4, 63, 2 };
    pub const configName = [_][]const u8{ "algo", "mix", "shift", "LCG" };
    pub const Config = [4]usize;
    pub const Seed = u64;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    fn init(seed: Seed, config: Config) Data {
        for (config) |conf, c| {
            if (conf >= configSize[c]) @panic("Invalid config");
        }
        var self = Data{ .state = seed *% dev.oddPhiFraction(Seed), .config = config };
        return self;
    }

    fn algo(data: *Data, value: Seed) Out {
        switch (data.config[0]) {
            0 => {
                data.mix(value);
                data.shift();
                data.mul();
            },
            1 => {
                data.mix(value);
                data.mul();
                data.shift();
            },
            2 => {
                data.shift();
                data.mix(value);
                data.mul();
            },
            3 => {
                data.shift();
                data.mul();
                data.mix(value);
            },
            4 => {
                data.mul();
                data.mix(value);
                data.shift();
            },
            5 => {
                data.mul();
                data.shift();
                data.mix(value);
            },
            else => unreachable,
        }
        return @intCast(Out, data.state >> @bitSizeOf(Seed) - @bitSizeOf(Out));
    }

    fn mix(data: *Data, value: Seed) void {
        const t = value;
        switch (data.config[1]) {
            0 => data.state ^= t,
            1 => data.state +%= t,
            2 => data.state -%= t,
            3 => data.state = t -% data.state,
            else => unreachable,
        }
    }

    fn shift(data: *Data) void {
        data.state ^= data.state >> @intCast(std.math.Log2Int(Seed), data.config[2] + 1);
    }

    fn mul(data: *Data) void {
        data.state *%= if (data.config[3] == 1) dev.harmonicLCG(Seed) else dev.harmonicMCG(Seed);
    }

    const Data = NonDeter32Data;
    const Base = @This();
};

var initialized = false;
var h: u64 = undefined;
var s: u64 = undefined;
var tI: u64 = undefined;

pub const Mix64 = struct {
    state: Seed,
    config: Config,
    counter: Seed = 0,

    pub fn init(seed: Seed, config: Config) Self {
        for (config) |conf, c| {
            if (conf >= configSize[c]) @panic("Invalid config");
        }
        if (!initialized) {
            defer initialized = true;
            const p = std.heap.page_allocator.create(u1) catch unreachable;
            std.heap.page_allocator.destroy(p);
            h = @ptrToInt(p);
            s = @ptrToInt(&p);
            tI = std.Thread.getCurrentId();
        }
        return Self{ .state = seed *% dev.oddPhiFraction(Seed), .config = config };
    }

    pub fn next(self: *Self) Out {
        defer self.counter += 1000;
        self.algo(self.counter);
        // self.algo(s);
        // self.algo(h);
        // self.algo(tI);
        return self.state;
    }

    pub const bestKnown = Config{ 0, 1, 6, 1 }; // round4: order: 20, quality: 13.127388403133672
    pub const configSize = Config{ 6, 4, 31, 2 };
    pub const configName = [_][]const u8{ "algo", "mix", "shift", "LCG" };
    pub const Config = [4]usize;
    pub const Seed = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    fn algo(self: *Self, value: Seed) void {
        switch (self.config[0]) {
            0 => {
                self.mix(value);
                self.shift();
                self.mul();
            },
            1 => {
                self.mix(value);
                self.mul();
                self.shift();
            },
            2 => {
                self.shift();
                self.mix(value);
                self.mul();
            },
            3 => {
                self.shift();
                self.mul();
                self.mix(value);
            },
            4 => {
                self.mul();
                self.mix(value);
                self.shift();
            },
            5 => {
                self.mul();
                self.shift();
                self.mix(value);
            },
            else => unreachable,
        }
    }

    fn mix(self: *Self, value: Seed) void {
        const t = value;
        switch (self.config[1]) {
            0 => self.state ^= t,
            1 => self.state +%= t,
            2 => self.state -%= t,
            3 => self.state = t -% self.state,
            else => unreachable,
        }
    }

    fn shift(self: *Self) void {
        self.state ^= self.state >> @intCast(std.math.Log2Int(Seed), self.config[2] + 1);
    }

    fn mul(self: *Self) void {
        self.state *%= if (self.config[3] == 1) dev.harmonicLCG(Seed) else dev.harmonicMCG(Seed);
    }

    const Self = @This();
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
