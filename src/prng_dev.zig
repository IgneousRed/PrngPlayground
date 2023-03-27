const lib = @import("lib.zig");

pub fn oddPhiFraction(comptime T: type) T {
    return lib.phiFraction(T) | 1;
}

pub fn spectralTest(comptime T: type, multiplier: T, dimensions: u5) []f64 {
    // TODO: Constify

    // S1: Initialize
    // var t: u5 = 2;
    var h: T = multiplier;
    var hp: i128 = 1 << @bitSizeOf(T);
    var p: i128 = 1;
    var pp: i128 = 0;
    // var r: i128 = multiplier;
    var s: i128 = 1 + multiplier * multiplier;

    //S2: Euclidean step
    var u: f64 = undefined;
    var v: f64 = undefined;
    while (true) {
        const q: f64 = hp / h;
        u = hp - q * h;
        v = pp - q * p;
        const uvSq = u * u + v * v;
        if (uvSq >= s) {
            break;
        }
        s = uvSq;
        hp = h;
        h = u;
        pp = p;
        p = u;
    }

    // S3: Compute V2
    u -= h;
    v -= p;
    const uvSq = u * u + v * v;
    if (uvSq < s) {
        s = uvSq;
        hp = u;
        pp = v;
    }
    _ = dimensions;
}

fn permutation64(value: u64) u64 {
    const mixed = (value >> @intCast(u6, (value >> 59) + 5) ^ value) *% 0xaef17502108ef2d9;
    return mixed >> 43 ^ mixed;
}

pub const preferredMultiplierMCG64 = 0xbdcdbb079f8d; // u48
pub const preferredMultiplierLCG64 = 0xd1342543de82ef95; // u64
pub const preferredMultiplierMCG128 = 0xdefba91144f2b375; // u64
