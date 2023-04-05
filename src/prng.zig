const std = @import("std");
const lib = @import("lib.zig");
const bits = @import("bits.zig");
const dev = @import("prng_dev.zig");

/// Hash64 calculates a seemingly random u64 from multiple u64s.
pub const Hash64 = struct {
    state: u64,

    /// Initialize Hash64 with a seed. Seeding with the last hash result should be considered.
    pub fn init(seed: u64) Self {
        return Self{ .state = seed };
    }

    /// Add entropy to the result.
    pub fn mix(self: *Self, value: u64) void {
        self.state -%= value ^ dev.harmonic64MCG64;
    }

    /// Conclude the calculation and get the result.
    pub fn done(self: *Self) u64 {
        var result = (self.state ^ self.state >> 32) *% dev.harmonic64MCG64;
        result = (result ^ result >> 32) *% dev.harmonic64MCG64;
        result = (result ^ result >> 32) *% dev.harmonic64MCG64;
        return result ^ result >> 32;
    }

    //////// Internal ////////

    const Self = @This();
};

/// Returns a random u64 by hashing last output and current time.
pub fn entropy64() u64 {
    var hash64 = Hash64.init(entropy64State);
    hash64.mix(@truncate(u64, @bitCast(u128, std.time.nanoTimestamp())));
    entropy64State = hash64.done();
    return entropy64State;
}

pub fn entropy128() u128 {
    return @intCast(u128, entropy64()) << 64 | entropy64();
}

/// Fastest PRNG with period of 2^62 32bit outputs. Statistically sound for 2^24 sequential bytes.
/// Perfect for games.
pub const MCG32 = struct {
    state: u64,

    pub usingnamespace Common(Self);

    /// Initialize with seed.
    pub fn init(seed: u64) Self {
        return Self{ .state = seed *% 2 + 1 };
    }

    /// Returns a random number from multiple u32s.
    pub fn int(self: *Self, comptime T: type) T {
        std.debug.assert(@typeInfo(T) == .Int);
        const bitSize = @bitSizeOf(T);
        switch (bitSize) {
            0 => @compileError("Expected: T == non-zero"),
            1...32 => return bits.high(T, self.advance()),
            else => {
                var result: T = 0;
                comptime var wordBits = @divTrunc(bitSize, 32) * 32;
                const remainingBits = bitSize - wordBits;
                if (remainingBits > 0) {
                    result = @as(T, self.int(bits.Unsigned(remainingBits))) << wordBits;
                }
                inline while (wordBits > 0) {
                    wordBits -= 32;
                    result |= @as(T, self.int(u32)) << wordBits;
                }
                return result;
            },
        }
    }

    //////// Internal ////////

    const Self = @This();

    /// Advances the state.
    fn advance(self: *Self) u64 {
        self.state *%= dev.preferredMultiplierMCG64;
        return self.state;
    }
};

/// Statistically random fast PRNG with period of 2^64 32bit outputs.
/// Statistically sound for 2^45+ sequential bytes. Sufficient for Monte Carlo Simulations.
/// Extrapolation from half sized version suggests statisticall soundness for
/// roughly 2^55 sequential bytes.
pub const PCG32 = struct {
    state: u64,

    pub usingnamespace Common(Self);

    /// Initialize with seed.
    pub fn init(seed: u64) Self {
        return Self{ .state = seed };
    }

    // pub fn u(self: *Self, comptime bits: comptime_int) U(bits) {}

    /// Returns a random number from multiple u32s.
    pub fn int(self: *Self, comptime T: type) T {
        std.debug.assert(@typeInfo(T) == .Int);
        const bitSize = @bitSizeOf(T);
        switch (bitSize) {
            0 => @compileError("Expected T == non-zero"),
            8 => {
                // const both =
                const Rotation = bits.ShiftType(T);
                const state = bits.high(@bitSizeOf(Rotation) + bitSize, self.advance());
                const source = state ^ state >> @bitSizeOf(state) / 2;
                return bits.ror(T, @truncate(T, source), bits.high(Rotation, state));
            },
            else => {
                var result: T = 0;
                comptime var wordBits = @divTrunc(bitSize, 32) * 32;
                const remainingBits = bitSize - wordBits;
                if (remainingBits > 0) {
                    result = @as(T, self.int(std.meta.Int(.unsigned, remainingBits))) << wordBits;
                }
                inline while (wordBits > 0) {
                    wordBits -= 32;
                    result |= @as(T, self.int(u32)) << wordBits;
                }
                return result;
            },
        }
    }

    /// Returns a random u8.
    pub fn next8(self: *Self) u8 {
        const state = bits.high(u11, self.advance());
        const source = state ^ state >> (3 + 8) / 2;
        return bits.ror8(@truncate(u8, source), @intCast(u3, state >> 8));
    }

    /// Returns a random u16.
    pub fn next16(self: *Self) u16 {
        const state = bits.high(u20, self.advance());
        const source = state ^ state >> (4 + 16) / 2;
        return bits.ror16(@truncate(u16, source), @intCast(u4, state >> 16));
    }

    /// Returns a random u32. Faster than `next64()`.
    pub fn next32(self: *Self) u32 {
        const state = bits.high(u37, self.advance());
        const source = state ^ state >> (5 + 32) / 2;
        return bits.ror32(@truncate(u32, source), @intCast(u5, state >> 32));
    }

    /// Returns a random u64. Slower than `next32()`.
    pub fn next64(self: *Self) u64 {
        return @intCast(u64, self.next32()) << 32 | self.next32();
    }

    /// Returns a random u128. Slower than `next64()`.
    pub fn next128(self: *Self) u128 {
        return @intCast(u128, self.next64()) << 64 | self.next64();
    }

    //////// Internal ////////

    const Self = @This();

    /// Advances the state.
    fn advance(self: *Self) u64 {
        self.state = self.state *% dev.preferredMultiplierLCG64 +% dev.oddPhiFraction(u64);
        return self.state;
    }
};

/// Statistically random fast PRNG with period of 2^126 64bit outputs.
/// Statistically sound for 2^45++ sequential bytes. Sufficient for Monte Carlo Simulations.
/// Extrapolation from half sized version suggests statisticall soundness for
/// roughly 2^75 sequential bytes.
pub const MCG64 = struct {
    state: u128,

    /// Initialize with seed.
    pub fn init(seed: u128) Self {
        return Self{ .state = seed *% 2 + 1 };
    }

    /// Initialize with random seed.
    pub fn new() Self {
        return Self.init(entropy128());
    }

    /// Returns a random u8.
    pub fn next8(self: *Self) u8 {
        const state = bits.high(u11, self.advance());
        return bits.ror8(@truncate(u8, state), bits.high(u3, state));
    }

    /// Returns a random u16.
    pub fn next16(self: *Self) u16 {
        const state = bits.high(u20, self.advance());
        return bits.ror16(@truncate(u16, state), bits.high(u4, state));
    }

    /// Returns a random u32.
    pub fn next32(self: *Self) u32 {
        const state = bits.high(u37, self.advance());
        return bits.ror32(@truncate(u32, state), bits.high(u5, state));
    }

    /// Returns a random u64. Faster than `next128()`.
    pub fn next64(self: *Self) u64 {
        const state = bits.highBits(70, self.advance());
        return bits.ror64(@truncate(u64, state), bits.highBits(6, state));
    }

    /// Returns a random u128. Slower than `next64()`.
    pub fn next128(self: *Self) u128 {
        return bits.concat(u128, self.next64(), self.next64());
    }

    /// Returns a number in range [0, n).
    pub fn range8(self: *Self, n: u8) u8 {
        if (n < 2) {
            return 0;
        }
        const t = -%n / n;
        while (true) {
            const value = self.next8();
            if (value >= t) {
                return value % n;
            }
        }
    }

    /// Returns a number in range [0, n).
    pub fn range16(self: *Self, n: u16) u16 {
        if (n < 2) {
            return 0;
        }
        const t = -%n / n;
        while (true) {
            const value = self.next16();
            if (value >= t) {
                return value % n;
            }
        }
    }

    /// Returns a number in range [0, n).
    pub fn range32(self: *Self, n: u32) u32 {
        if (n < 2) {
            return 0;
        }
        const t = -%n / n;
        while (true) {
            const value = self.next32();
            if (value >= t) {
                return value % n;
            }
        }
    }

    /// Returns a number in range [0, n). Faster than `range128()`.
    pub fn range64(self: *Self, n: u64) u64 {
        if (n < 2) {
            return 0;
        }
        const t = -%n / n;
        while (true) {
            const value = self.next64();
            if (value >= t) {
                return value % n;
            }
        }
    }

    /// Returns a number in range [0, n). Slower than `range64()`.
    pub fn range128(self: *Self, n: u128) u128 {
        if (n < 2) {
            return 0;
        }
        const t = -%n / n;
        while (true) {
            const value = self.next128();
            if (value >= t) {
                return value % n;
            }
        }
    }

    /// Return an f16 in range [0, 1).
    pub fn float16(self: *Self) f16 {
        @setFloatMode(.Optimized);
        return @intToFloat(f16, @truncate(u11, self.next16())) * 0x1p-11;
    }

    /// Return an f32 in range [0, 1).
    pub fn float32(self: *Self) f32 {
        @setFloatMode(.Optimized);
        return @intToFloat(f32, @truncate(u24, self.next32())) * 0x1p-24;
    }

    /// Return an f64 in range [0, 1).
    pub fn float64(self: *Self) f64 {
        @setFloatMode(.Optimized);
        return @intToFloat(f64, @truncate(u53, self.next64())) * 0x1p-53;
    }

    /// Return an f80 in range [0, 1).
    pub fn float80(self: *Self) f80 {
        @setFloatMode(.Optimized);
        return @intToFloat(f80, self.next64()) * 0x1p-64;
    }

    /// Return an f128 in range [0, 1).
    pub fn float128(self: *Self) f128 {
        @setFloatMode(.Optimized);
        return @intToFloat(f128, @truncate(u113, self.next128())) * 0x1p-113;
    }

    //////// Internal ////////

    const Self = @This();

    /// Advances the state.
    fn advance(self: *Self) u128 {
        self.state *%= dev.harmonic128MCG128;
        return self.state;
    }
};

//////// Internal ////////

var entropy64State: u64 = 0x9e3779b97f4a7c15;

fn Common(comptime Self: type) type {
    return struct {
        /// Initialize with random seed.
        pub fn new() Self {
            return Self.init(entropy64());
        }

        /// Returns type T unsigned number in range [0, n).
        pub fn range(self: *Self, comptime T: type, mod: T) T {
            std.debug.assert(@typeInfo(T).Int.signedness == .unsigned);
            if (mod < 2) {
                return 0;
            }
            const mask = ~@as(T, 0) >> bits.shiftCast(T, @clz(mod - 1 | 1));
            while (true) {
                const value = self.int(T) & mask;
                // std.debug.print("{}, {}, {}\n", .{ mod, mask, value });
                if (value < mod) {
                    return value;
                }
            }
        }

        /// Returns a float T in range [0, 1).
        pub fn float(self: *Self, comptime T: type) T {
            @setFloatMode(.Optimized);
            return switch (T) {
                f16 => @intToFloat(f16, self.int(u11)) * 0x1p-11,
                f32 => @intToFloat(f32, self.int(u24)) * 0x1p-24,
                f64 => @intToFloat(f64, self.int(u53)) * 0x1p-53,
                f80 => @intToFloat(f80, self.int(u64)) * 0x1p-64,
                f128 => @intToFloat(f128, self.int(u113)) * 0x1p-113,
                else => @compileError("Expected: T == float"),
            };
        }
    };
}
