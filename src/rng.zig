const std = @import("std");
const dev = @import("rngDev.zig");
const bits = @import("bits.zig");

pub fn JSF(comptime T: type) type {
    const consts = [4][3]comptime_int{ .{ 7, 4, 0 }, .{ 3, 8, 0 }, .{ 29, 18, 8 }, .{ 57, 51, 27 } };
    const k = switch (T) {
        else => @compileError("JSF supports: u64, u32, u16, u8"),
        u8, u16, u32, u64 => consts[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Out,
        pub fn init(seed: Seed) Self {
            var self: Self = .{ .state = .{ seed, ~seed, -%seed, ~-%seed | bits.ror(@as(Out, 1), 1) } };
            for (0..4) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Out {
            const temp = self.state[0] -% bits.ror(self.state[1], k[0]);
            self.state[0] = self.state[1] ^ bits.ror(self.state[2], k[1]);
            self.state[1] = self.state[2] +% bits.ror(self.state[3], k[2]);
            self.state[2] = self.state[3] +% temp;
            self.state[3] = temp +% self.state[0];
            return self.state[3];
        }
        pub const Out = T;
        pub const Seed = Out;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

pub fn GJR(comptime T: type) type {
    const consts = [4][3]comptime_int{ .{ 4, 6, 3 }, .{ 8, 11, 6 }, .{ 16, 21, 13 }, .{ 32, 41, 45 } };
    const k = switch (T) {
        else => @compileError("GJR supports: u8, u16, u32, u64"),
        u8, u16, u32, u64 => consts[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Out,
        pub fn init(seed: Seed) Self {
            var self: Self = .{ .state = .{ seed, ~seed, -%seed, ~-%seed } };
            for (0..4) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Out {
            const a = self.state[2] +% self.state[1];
            const b = bits.ror(self.state[3], k[0]) +% a;
            const c = bits.ror(self.state[1] ^ a, k[1]);
            self.state[3] = b +% c;
            self.state[2] = bits.ror(a ^ b, k[2]) +% self.state[0];
            self.state[1] = c +% self.state[3];
            self.state[0] +%= dev.oddPhiFraction(Out);
            return a;
        }
        pub const Out = T;
        pub const Seed = Out;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

pub fn SFC(comptime T: type) type {
    const consts = [4][3]comptime_int{ .{ 3, 2, 7 }, .{ 3, 2, 12 }, .{ 9, 3, 11 }, .{ 11, 3, 40 } };
    const k = switch (T) {
        else => @compileError("SFC supports: u8, u16, u32, u64"),
        u8, u16, u32, u64 => consts[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Out,
        pub fn init(seed: Seed) Self {
            var self: Self = .{ .state = .{ seed, ~seed, -%seed, ~-%seed } };
            for (0..10) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Out {
            const result = self.state[0] +% self.state[1] +% self.state[3];
            self.state[0] = self.state[1] ^ (self.state[1] >> k[0]);
            self.state[1] = self.state[2] +% (self.state[2] << k[1]);
            self.state[2] = bits.ror(self.state[2], k[2]) +% result;
            self.state[3] +%= dev.oddPhiFraction(Out);
            return result;
        }
        pub const Out = T;
        pub const Seed = Out;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

// 8:   16, 27
// 16:  30, 4
// 32:  4, 4
// 64:  4, 4
pub fn MWC3(comptime T: type, comptime permuted: bool) type {
    const consts = [4][3]comptime_int{
        .{ 0x4e, 0x38, 0xe4 }, // Find better constants
        .{ 0x814f, 0xf767, 0x9969 }, // Find better constants
        .{ 0xd15e_a5e5, 0xcafef00d, 0xcfdb_c53d }, // TODO: Better mul exists?
        .{ 0x1405_7b7e_f767_814f, 0xcafe_f00d_d15e_a5e5, 0xfeb3_4465_7c0a_f413 },
    };
    const k = switch (T) {
        else => @compileError("MWC3 supports: u8, u16, u32, u64"),
        u8, u16, u32, u64 => consts[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Out,
        pub fn init(seed: Seed) Self {
            var self: Self = .{ .state = .{ k[0], k[1], ~seed, seed } };
            for (0..6) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Out {
            const mul = bits.multiplyFull(self.state[1], k[2]) +% self.state[0];
            const result = if (permuted)
                self.state[0] +% self.state[3]
            else
                bits.low(Out, mul);
            self.state[0] = bits.high(Out, mul);
            self.state[1] = self.state[2];
            self.state[2] = self.state[3];
            self.state[3] = bits.low(Out, mul);
            return result;
        }
        pub const Out = T;
        pub const Seed = Out;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

pub fn WYR(comptime T: type) type {
    if (T != u32 and T != u64) @compileError("WYR supports: u32, u64");
    const k = ([2][2]comptime_int{
        .{ 0x53c5_ca59, 0x7474_3c1b },
        .{ 0x8bb8_4b93_962e_acc9, 0x2d35_8dcc_aa6c_78a5 },
    })[@intFromBool(T == u64)];

    return struct {
        state: [1]Out,
        pub fn init(seed: Seed) Self {
            return .{ .state = .{~seed *% dev.oddPhiFraction(Out)} };
        }
        pub fn next(self: *Self) Out {
            const mul = bits.multiplyFull(self.state[0], self.state[0] ^ k[0]);
            self.state[0] +%= k[1];
            return bits.low(Out, mul) ^ bits.high(Out, mul);
        }
        pub const Out = T;
        pub const Seed = Out;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

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
