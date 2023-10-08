const std = @import("std");
const mem = std.mem;
const math = std.math;
const bits = @import("bits.zig");
const Allocator = std.mem.Allocator;

/// Assumes State[0] T == Out T
/// Segfault if
pub fn quickTest(comptime Rng: type, frequency: usize, sampleCount: u32, alloc: Allocator) !f64 {
    const results = try quickTestRaw(Rng, frequency, sampleCount, alloc);
    defer alloc.free(results);
    return harmonicSum(results);
}

pub fn harmonicSum(slice: []const f64) f64 {
    var result: f64 = 0.0;
    var iSum: f64 = 0;
    for (slice, 1..) |v, i| {
        const amount = 1 / @as(f64, @floatFromInt(i));
        result += v * amount;
        iSum += amount;
    }
    return result / iSum;
}

/// Assumes State[0] T == Out T
pub fn quickTestRaw(comptime Rng: type, frequency: usize, sampleCount: u32, alloc: Allocator) ![]f64 {
    var rng = Rng.init(0);

    const T = @TypeOf(rng.state[0]);
    const wordBitCount = @bitSizeOf(T);
    const wordCount = rng.state.len;

    var buckets = try alloc.alloc([wordCount * wordBitCount][wordBitCount]usize, frequency);
    defer alloc.free(buckets);
    for (buckets) |*freq| for (freq) |*bit| for (bit) |*tes| {
        tes.* = 0;
    };

    var rngStates = try alloc.alloc([wordCount]T, frequency);
    defer alloc.free(rngStates);
    for (0..frequency - 1) |i| {
        rngStates[i] = rng.state;
        _ = rng.next();
    }
    for (0..sampleCount) |_| {
        rngStates[frequency - 1] = rng.state;
        const original = rng.next();
        for (buckets, 0..) |*freq, f| {
            for (freq, 0..) |*bit, b| {
                var rngCopy: Rng = undefined;
                rngCopy.state = rngStates[frequency - 1 - f];
                rngCopy.state[b / wordBitCount] ^= bits.shl(@as(T, 1), b % wordBitCount);
                for (0..f) |_| _ = rngCopy.next();
                const xor = rngCopy.next() ^ original;
                bit[0] += pop(xor);
                for (1..wordBitCount) |w| {
                    bit[w] += pop(xor ^ bits.rol(xor, w));
                }
            }
        }
        mem.copyForwards([wordCount]T, rngStates[0..], rngStates[1..]);
    }

    const treshold = avelancheAverage(T);
    var result = try alloc.alloc(f64, frequency);
    for (buckets, 0..) |freq, f| {
        var freqResult: f64 = math.inf(f64);
        for (freq) |bit| {
            for (bit) |val| {
                const avel = bits.usizeToF64(val) / bits.usizeToF64(sampleCount);
                freqResult = @min(freqResult, treshold / @fabs(avel - treshold));
            }
        }
        result[f] = freqResult;
    }
    return result;
}

fn pop(val: anytype) usize {
    const bitCount = @bitSizeOf(@TypeOf(val));
    const count = @popCount(val);
    if (count > bitCount >> 1) {
        return bitCount - count;
    }
    return count;
}

fn avelancheAverage(comptime T: type) f64 {
    const full = @bitSizeOf(T);
    @setEvalBranchQuota(full * 2);
    const half = full / 2;
    comptime var fact = mem.zeroes([full + 1]comptime_int);
    fact[0] = 1;
    comptime var i: comptime_int = 1;
    inline while (i <= full) : (i += 1) {
        fact[i] = fact[i - 1] * i;
    }
    comptime var bucket: comptime_int = 0;
    i = 0;
    inline while (i < half) : (i += 1) {
        bucket += fact[full] / (fact[i] * fact[full - i]) * i << 1;
    }
    bucket += fact[full] / (fact[half] * fact[full - half]) * half;
    return @as(f64, @floatFromInt(bucket)) / @as(f64, @floatFromInt(1 << full));
}
