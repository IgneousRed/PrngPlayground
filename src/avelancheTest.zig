const std = @import("std");
const bits = @import("bits.zig");
const Allocator = std.mem.Allocator;

pub fn avelancheTest(
    comptime Rng: type,
    comptime frequency: usize,
    sampleCount: usize,
) Avelanche(Rng) {
    var rng = Rng.init(0);

    const nameMePlz = frequency - 1; // TODO: Name
    const Word = @TypeOf(rng.state[0]);
    const wordBits = @bitSizeOf(Word);
    const words = rng.state.len;
    const stateBits = words * wordBits;

    var buckets = std.mem.zeroes([stateBits][2]u32);
    var rngStates: [frequency][words]Word = undefined;
    var s: usize = 0;
    while (s < nameMePlz) : (s += 1) {
        rngStates[s] = rng.state;
        _ = rng.next();
    }
    rngStates[nameMePlz] = rng.state;
    var rngCopy = rng;

    var i: usize = 0;
    while (i < sampleCount) : (i += 1) {
        const original = rng.next();
        var b: usize = 0;
        while (b < stateBits) : (b += 1) {
            rngCopy.state = rngStates[0];
            rngCopy.state[b / wordBits] ^= bits.shl(@as(Word, 1), b % wordBits);
            var f: usize = 0;
            while (f < nameMePlz) : (f += 1) _ = rngCopy.next();
            const xor = rngCopy.next() ^ original;
            buckets[b][0] += @popCount(xor);
            buckets[b][1] += @popCount(bits.rol(xor, 1) ^ xor);
        }
        std.mem.copy([words]Word, rngStates[0..], rngStates[1..]);
        rngStates[nameMePlz] = rng.state;
    }
    var result: Avelanche(Rng) = undefined;
    for (result) |*bit, b| {
        for (bit) |*tes, t| {
            tes.* = @intToFloat(f64, buckets[b][t]) / @intToFloat(f64, sampleCount);
        }
    }
    return result;
}

pub fn avelancheSummary(comptime Rng: type, avelanche: Avelanche(Rng)) void {
    const rng: Rng = undefined;
    const wordBits = @bitSizeOf(@TypeOf(rng.state[0]));

    var average: f64 = avelanche[0][0];
    var worstBit: usize = 0;
    var worstTest: usize = 0;
    var worst: f64 = score(average, wordBits);

    for (avelanche) |bit, b| {
        for (bit) |tes, t| {
            const sc = score(tes, wordBits);
            average += tes;
            if (worst > sc) {
                worstBit = b;
                worstTest = t;
                worst = sc;
            }
        }
    }
    average = score(average / @intToFloat(f64, avelanche.len * 2), wordBits);
    std.debug.print("average {d}, worst [{}][{}] {d}\n", .{ average, worstBit, worstTest, worst });
}

pub fn Avelanche(comptime Rng: type) type {
    const rng: Rng = undefined;
    const wordBits = @bitSizeOf(@TypeOf(rng.state[0]));
    const stateBits = rng.state.len * wordBits;
    return [stateBits][2]f64;
}

fn score(avelanche: f64, wordBits: f64) f64 {
    return 1.0 / @fabs(avelanche / wordBits * 2.0 - 1.0);
}
