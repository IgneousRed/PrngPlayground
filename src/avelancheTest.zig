const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn avelancheTest(comptime Rng: type, sampleCount: usize, alloc: Allocator) !Avelanche {
    var rng = Rng.init(0);

    const Word = @TypeOf(rng.state[0]);
    const wordBits = @bitSizeOf(Word);
    const words = rng.state.len;
    const stateBits = words * wordBits;

    var buckets = std.mem.zeroes([words][stateBits][wordBits][wordBits]usize);
    var rngStates: [words][words]Word = undefined;
    var s: usize = words - 1;
    while (s != 0) : (s -= 1) {
        rngStates[s] = rng.state;
        _ = rng.next();
    }
    rngStates[0] = rng.state;
    var rngCopy = rng;
    var i: usize = 0;
    while (i < sampleCount) : (i += 1) {
        const original = rng.next();
        var freq: usize = 0;
        while (freq < words) : (freq += 1) {
            var b: usize = 0;
            while (b < stateBits) : (b += 1) {
                rngCopy.state = rngStates[freq];
                rngCopy.state[b / wordBits] ^= shl(1, b % wordBits);
                var f: usize = 0;
                while (f < freq) : (f += 1) _ = rngCopy.next();
                const copy = rngCopy.next();
                var r: usize = 0;
                while (r < wordBits) : (r += 1) {
                    const xor = rol(copy, r) ^ original;
                    buckets[freq][b][r][0] += @popCount(xor);
                    var t: usize = 1;
                    while (t < wordBits) : (t += 1) {
                        buckets[freq][b][r][t] += rol(xor, t) ^ xor;
                    }
                }
            }
        }
        s = words - 1;
        while (s != 0) : (s -= 1) {
            rngStates[s] = rngStates[s - 1];
        }
        rngStates[0] = rng.state;
    }
    var result: [][][]f32 = try alloc.alloc([][]f32, words);
    for (result) |*freq, f| {
        freq.* = try alloc.alloc([]f32, wordBits);
        for (freq) |*bit, b| {
            bit.* = try alloc.alloc(f32, stateBits);
            for (bit) |*tes, t| {
                tes.* = @intToFloat(f32, buckets[f][t][b]) / @intToFloat(f32, sampleCount);
            }
        }
    }
    return result;
}

// pub fn printAvelanche(avelanche: Avelanche, wordBits: u8) void {
//     const wBits = @intToFloat(f32, wordBits);
//     // var all: f32 = undefined;
//     // var freq: []f32 = undefined;
//     for (avelanche) |tes, t| {
//         for (tes) |bit, b| {
//             var worst = score(bit[0], wBits);
//             for (bit[0..]) |ave, a| {}
//         }
//     }
// }

pub const Avelanche = [][][]f32; // [frequency][test][bit]averageAvelanche

fn score(avelanche: f32, wordBits: f32) f32 {
    const normalized = avelanche / wordBits;
    if (normalized > 0.5) std.debug.print("KEK", .{avelanche});
    return 1.0 / @fabs(normalized * 2.0 - 1.0);
}

pub fn shl(value: anytype, amount: anytype) @TypeOf(value) {
    return value << @intCast(std.math.Log2Int(@TypeOf(value)), amount);
}

pub fn shr(value: anytype, amount: anytype) @TypeOf(value) {
    return value >> @intCast(std.math.Log2Int(@TypeOf(value)), amount);
}

pub fn rol(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @intCast(std.math.Log2Int(@TypeOf(value)), amount);
    return value << a | value >> -%a;
}
