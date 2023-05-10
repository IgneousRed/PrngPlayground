const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn avelancheTest(comptime Rng: type, sampleCount: usize) Avelanche(Rng) {
    var rng = Rng.init(0);

    const words = rng.state.len;
    const Word = @TypeOf(rng.state[0]);
    const wordBits = @bitSizeOf(Word);
    const stateBits = words * wordBits;

    var buckets = std.mem.zeroes([words * 2][stateBits][2]u32);
    var rngStates: [words * 2][words]Word = undefined;
    var s: usize = words * 2 - 1;
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
                rngCopy.state[b / wordBits] ^= shl(@as(Word, 1), b % wordBits);
                var f: usize = 0;
                while (f < freq) : (f += 1) _ = rngCopy.next();
                const xor = rngCopy.next() ^ original;
                buckets[freq][b][0] += @popCount(xor);
                buckets[freq][b][1] += @popCount(rol(xor, 1) ^ xor);
            }
        }
        s = words * 2 - 1;
        while (s != 0) : (s -= 1) {
            rngStates[s] = rngStates[s - 1];
        }
        rngStates[0] = rng.state;
    }
    var result: Avelanche(Rng) = undefined;
    for (result) |*freq, f| {
        for (freq) |*bit, b| {
            for (bit) |*tes, t| {
                tes.* = @intToFloat(f64, buckets[f][b][t]) / @intToFloat(f64, sampleCount);
                std.debug.print("freq: {}, bit: {} test: {} => {d}\n", .{ f, b, t, tes.* });
            }
        }
    }
    return result;
}

// pub fn printAvelanche(avelanche: Avelanche, wordBits: u8) void {
//     const wBits = @intToFloat(f64, wordBits);
//     // var all: f64 = undefined;
//     // var freq: []f64 = undefined;
//     for (avelanche) |tes, t| {
//         for (tes) |bit, b| {
//             var worst = score(bit[0], wBits);
//             for (bit[0..]) |ave, a| {}
//         }
//     }
// }
pub fn Avelanche(comptime Rng: type) type {
    const rng: Rng = undefined;
    const words = rng.state.len;
    const wordBits = @bitSizeOf(@TypeOf(rng.state[0])); // TODO: Extract?
    const stateBits = words * wordBits;
    return [words * 2][stateBits][2]f64;
}
fn score(avelanche: f64, wordBits: f64) f64 {
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

// TODO: Try offsets
