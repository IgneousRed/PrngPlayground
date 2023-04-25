const std = @import("std");
const dev = @import("rng_dev.zig");

pub const NonDeter32Config = struct { // TODO: Ask about soltion for BaseI
    pub usingnamespace Base;

    base: Base,

    counter: Base.State = 0,

    pub fn init(seed: Base.State, config: Base.Config) Self {
        return .{ .base = Base.initBase(seed, config) };
    }

    pub fn gen(self: *Self) Base.Out {
        defer self.counter += 1000;
        return self.base.mixIn(self.counter);
    }

    // -------------------------------- Internal --------------------------------

    const Base = NonDeter32Base;
    const Self = @This();
};

pub const NonDeter32 = struct {
    pub usingnamespace Base;

    base: Base,

    pub fn init(seed: Base.State, config: Base.Config) NonDeter32 {
        var self = .{ .base = Base.initBase(seed, config) };
        runEntropy64(&self.base.state);
        return self;
    }

    pub fn gen(self: *Self) Base.Out {
        return self.base.mixIn(time64());
    }

    // -------------------------------- Internal --------------------------------

    const Base = NonDeter32Base;
    const Self = @This();
};

const NonDeter32Base = struct {
    state: State,
    config: Config,

    pub fn initBase(seed: State, config: Config) Base {
        for (config) |conf, c| {
            if (conf >= configSize[c]) @panic("Invalid config");
        }
        var self = Base{ .state = seed *% dev.oddPhiFraction(State), .config = config };
        return self;
    }

    pub const bestKnown = Config{ 0, 22, 1 }; // round4: order: 20, quality: 13.131536748683057
    pub const configSize = Config{ 4, 63, 2 };
    pub const configName = [_][]const u8{ "mix", "shift", "LCG" };
    pub const Config = [3]usize;
    pub const State = u64;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    fn mixIn(self: *Base, value: State) Out {
        const t = value;
        switch (self.config[0]) {
            0 => self.state ^= t,
            1 => self.state +%= t,
            2 => self.state -%= t,
            3 => self.state = t -% self.state,
            else => unreachable,
        }
        self.state ^= self.state >> @intCast(std.math.Log2Int(State), self.config[1] + 1);
        self.state *%= if (self.config[2] == 1) dev.harmonicLCG(State) else dev.harmonicMCG(State);

        return @intCast(Out, self.state >> @bitSizeOf(State) - @bitSizeOf(Out));
    }

    const Base = @This();
};

// Config{ 3, 8, 1 }; // round4: order: 20, quality: 7.335778683837248

pub fn runEntropy64(state: *u64) void {
    const alloc = std.heap.page_allocator;
    const heap = alloc.create(u1) catch unreachable;
    alloc.destroy(heap);
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

// TODO: Skip same config
// TODO: Write and Read run results in files
