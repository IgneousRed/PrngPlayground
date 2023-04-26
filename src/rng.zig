const std = @import("std");
const dev = @import("rng_dev.zig");

pub const NonDeter32Config = struct {
    pub usingnamespace Base;

    data: Data,
    counter: Base.State = 0,

    pub fn init(seed: Base.State, config: Base.Config) Self {
        return .{ .data = Base.init(seed, config) };
    }

    pub fn gen(self: *Self) Base.Out {
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

    pub fn init(seed: Base.State, config: Base.Config) Self {
        var self = .{ .data = Base.init(seed, config) };
        runEntropy64(&self.data.state);
        return self;
    }

    pub fn gen(self: *Self) Base.Out {
        return Base.algo(&self.data, time64());
    }

    // -------------------------------- Internal --------------------------------

    const Data = NonDeter32Data;
    const Base = NonDeter32Base;
    const Self = @This();
};

const NonDeter32Data = struct {
    usingnamespace NonDeter32Base;

    state: NonDeter32Base.State,
    config: NonDeter32Base.Config,
};

const NonDeter32Base = struct {
    pub const bestKnown = Config{ 0, 3, 21, 1 }; // round4: order: 20, quality: 13.131536748683057
    pub const configSize = Config{ 6, 4, 63, 2 };
    pub const configName = [_][]const u8{ "algo", "mix", "shift", "LCG" };
    pub const Config = [4]usize;
    pub const State = u64;
    pub const Out = u32;

    // -------------------------------- Internal --------------------------------

    fn init(seed: State, config: Config) Data {
        for (config) |conf, c| {
            if (conf >= configSize[c]) @panic("Invalid config");
        }
        var self = Data{ .state = seed *% dev.oddPhiFraction(State), .config = config };
        return self;
    }

    fn algo(data: *Data, value: State) Out {
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
        return @intCast(Out, data.state >> @bitSizeOf(State) - @bitSizeOf(Out));
    }

    fn mix(data: *Data, value: State) void {
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
        data.state ^= data.state >> @intCast(std.math.Log2Int(State), data.config[2] + 1);
    }

    fn mul(data: *Data) void {
        data.state *%= if (data.config[3] == 1) dev.harmonicLCG(State) else dev.harmonicMCG(State);
    }

    const Data = NonDeter32Data;
    const Base = @This();
};

var initialized = false;
var h: u64 = undefined;
var s: u64 = undefined;
var tI: u64 = undefined;

pub const Mix64 = struct {
    state: State,
    config: Config,
    counter: State = 0,

    pub fn init(seed: State, config: Config) Self {
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
        return Self{ .state = seed *% dev.oddPhiFraction(State), .config = config };
    }

    pub fn gen(self: *Self) Out {
        defer self.counter += 1000;
        self.algo(self.counter);
        // self.algo(s);
        // self.algo(h);
        // self.algo(tI);
        return self.state;
    }

    pub const bestKnown = Config{ 0, 1, 17, 1 }; // round4: order: 20, quality: 13.131536748683057
    pub const configSize = Config{ 6, 4, 31, 2 };
    pub const configName = [_][]const u8{ "algo", "mix", "shift", "LCG" };
    pub const Config = [4]usize;
    pub const State = u64;
    pub const Out = u64;

    // -------------------------------- Internal --------------------------------

    fn algo(self: *Self, value: State) void {
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

    fn mix(self: *Self, value: State) void {
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
        self.state ^= self.state >> @intCast(std.math.Log2Int(State), self.config[2] + 1);
    }

    fn mul(self: *Self) void {
        self.state *%= if (self.config[3] == 1) dev.harmonicLCG(State) else dev.harmonicMCG(State);
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
