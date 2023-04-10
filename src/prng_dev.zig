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

pub const harmonic32MCG32 = 0x93d765dd;
pub const harmonic32LCG24 = 0xc083c5;
pub const harmonic32LCG32 = 0x915f77f5;
pub const harmonic64MCG48 = 0xbdcdbb079f8d;
pub const harmonic64MCG64 = 0xf1357aea2e62a9c5;
pub const harmonic64LCG64 = 0xd1342543de82ef95;
pub const harmonic128MCG64 = 0xdefba91144f2b375;
pub const harmonic128MCG128 = 0xaadec8c3186345282b4e141f3a1232d5;
pub const harmonic128LCG67 = 0x77808d182e9136c35;
pub const harmonic128LCG128 = 0xdb36357734e34abb0050d0761fcdfc15;
pub const golden32 = 0x9e3779bd;
pub const golden64 = 0x9e3779b97f4a7c15;
pub const golden128 = 0x9e3779b97f4a7c15f39cc0605cedc835;
