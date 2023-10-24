const std = @import("std");
const dev = @import("rngDev.zig");
const bits = @import("bits.zig");

pub fn JSF(comptime T: type) type {
    const k = switch (T) {
        else => @compileError("JSF supports: u64, u32, u16, u8"),
        u8, u16, u32, u64 => .{
            .{ 7, 4, 0 },
            .{ 3, 8, 0 },
            .{ 29, 18, 8 },
            .{ 57, 51, 27 },
        }[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Word,
        pub fn init(seed: Word) Self {
            var self: Self = .{ .state = .{
                seed,
                ~seed,
                -%seed,
                ~-%seed | bits.ror(@as(Word, 1), 1),
            } };
            for (0..4) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Word {
            const temp = self.state[0] -% bits.ror(self.state[1], k[0]);
            self.state[0] = self.state[1] ^ bits.ror(self.state[2], k[1]);
            self.state[1] = self.state[2] +% bits.ror(self.state[3], k[2]);
            self.state[2] = self.state[3] +% temp;
            self.state[3] = temp +% self.state[0];
            return self.state[3];
        }
        pub const Word = T;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

pub fn SFC(comptime T: type) type {
    const k = switch (T) {
        else => @compileError("SFC supports: u8, u16, u32, u64"),
        u8, u16, u32, u64 => .{
            .{ 3, 2, 7 },
            .{ 3, 2, 12 },
            .{ 9, 3, 11 },
            .{ 11, 3, 40 },
        }[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Word,
        pub fn init(seed: Word) Self {
            var self: Self = .{ .state = .{ seed, ~seed, -%seed, ~-%seed } };
            for (0..10) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Word {
            const result = self.state[0] +% self.state[1] +% self.state[3];
            self.state[0] = self.state[1] ^ (self.state[1] >> k[0]);
            self.state[1] = self.state[2] +% (self.state[2] << k[1]);
            self.state[2] = bits.ror(self.state[2], k[2]) +% result;
            self.state[3] +%= dev.oddPhiFraction(Word);
            return result;
        }
        pub const Word = T;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

pub fn GJR(comptime T: type) type {
    const k = switch (T) {
        else => @compileError("GJR supports: u8, u16, u32, u64"),
        u8, u16, u32, u64 => .{
            .{ 4, 6, 3 },
            .{ 8, 11, 6 },
            .{ 16, 21, 13 },
            .{ 32, 41, 45 },
        }[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Word,
        pub fn init(seed: Word) Self {
            var self: Self = .{ .state = .{ seed, ~seed, -%seed, ~-%seed } };
            for (0..4) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Word {
            const a = self.state[2] +% self.state[1];
            const b = bits.ror(self.state[3], k[0]) +% a;
            const c = bits.ror(self.state[1] ^ a, k[1]);
            self.state[3] = b +% c;
            self.state[2] = bits.ror(a ^ b, k[2]) +% self.state[0];
            self.state[1] = c +% self.state[3];
            self.state[0] +%= dev.oddPhiFraction(Word);
            return a;
        }
        pub const Word = T;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

// PractRand-pre0.95 Expanded, Extra Folding
// Out  None                             Simple                      Complex
// 8    16 [Low8/32]FPF-14+6/4:(2,14-8)  27 [Low8/32]FPF-14+6/4:all  29 FPF-14+6/4:(2,14-0)
// 16   30 [Low1/8]FPF-14+6/4:all        >40                         >40
// 32   >40                              >40                         >40
// 64   >40                              >40                         >40
//
// Apple M2 Pro: NanoS/OP
// Out  Raw              Permuted
// 8    1.15966796875    0.9765625
// 16   0.8697509765625  0.9765625
// 32   1.4190673828125  1.4190673828125
// 64   0.5645751953125  0.5645751953125 TODO: Test again
pub fn MWC3(comptime T: type, comptime outputFn: MWCOutputFn) type {
    const k = switch (T) {
        else => @compileError("MWC3 supports: u8, u16, u32, u64"),
        u8, u16, u32, u64 => .{
            .{ 0x4e, 0x38, 0xe4 }, // Find better constants
            .{ 0x814f, 0xf767, 0x9969 }, // Find better constants
            .{ 0xd15ea5e5, 0xcafef00d, 0xcfdbc53d }, // Better mul exists?
            .{ 0x14057b7ef767814f, 0xcafef00dd15ea5e5, 0xfeb344657c0af413 },
        }[std.math.log2(@sizeOf(T))],
    };

    return struct {
        state: [4]Word,
        pub fn init(seed: Word) Self { // Make seed influence every state
            var self: Self = .{ .state = .{ k[0], k[1], ~seed, seed } };
            for (0..6) |_| _ = self.next();
            return self;
        }
        pub fn next(self: *Self) Word {
            const mul = bits.multiplyFull(self.state[1], k[2]) +% self.state[0];
            const result = switch (outputFn) {
                .none => bits.low(Word, mul),
                .simple => bits.low(Word, mul) +% bits.high(Word, mul),
                .complex => (self.state[1] ^ self.state[2]) +% (self.state[3] ^ bits.high(Word, mul)),
            };
            self.state[0] = bits.high(Word, mul);
            self.state[1] = self.state[2];
            self.state[2] = self.state[3];
            self.state[3] = bits.low(Word, mul);
            return result;
        }
        pub const Word = T;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}
pub const MWCOutputFn = enum { none, simple, complex };

// PractRand-pre0.95 Expanded, Extra Folding
// Out  Xor                          Sub
// 16   13 Gap-16:A                  13 Gap-16:A
// 32   29 Gap-16:A                  28 [Low1/8]FPF-14+6/16:all
// 64   45 [Low1/8]mod3n(0):(0,9-6)  >45
//
// Apple M2 Pro: NanoS/OP
// Out  Xor             Sub
// 16   0.1068115234375 0.0762939453125
// 32   0.2288818359375 0.1678466796875
// 64   0.3814697265625 0.3662109375
pub fn WYR(comptime T: type) type {
    const k = switch (T) {
        else => @compileError("WYR supports: u16, u32, u64"),
        u16, u32, u64 => .{
            .{ 0xca59, 0x53c5 },
            .{ 0x53c5ca59, 0x74743c1b },
            .{ 0x8bb84b93962eacc9, 0x2d358dccaa6c78a5 },
        }[std.math.log2(@sizeOf(T)) - 1],
    };

    return struct {
        state: [1]Word,
        pub fn init(seed: Word) Self {
            return .{ .state = .{~seed *% k[1]} };
        }
        pub fn next(self: *Self) Word {
            const mul = bits.multiplyFull(self.state[0], self.state[0] ^ k[0]);
            self.state[0] +%= k[1];
            // return bits.low(Word, mul) ^ bits.high(Word, mul);
            return bits.low(Word, mul) -% bits.high(Word, mul);
        }
        pub const Word = T;

        // -------------------------------- Internal --------------------------------
        const Self = @This();
    };
}

pub const Xoroshiro128 = struct {
    state: std.rand.Xoroshiro128,
    pub fn init(seed: Word) Self {
        return .{ .state = std.rand.Xoroshiro128.init(seed) };
    }
    pub fn next(self: *Self) Word {
        return self.state.random().int(Word);
    }
    pub const Word = u64;

    // -------------------------------- Internal --------------------------------
    const Self = @This();
};

pub const Xoshiro256 = struct {
    state: std.rand.Xoshiro256,
    pub fn init(seed: Word) Self {
        return .{ .state = std.rand.Xoshiro256.init(seed) };
    }
    pub fn next(self: *Self) Word {
        return self.state.random().int(Word);
    }
    pub const Word = u64;

    // -------------------------------- Internal --------------------------------
    const Self = @This();
};
