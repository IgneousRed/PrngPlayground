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

pub fn harmonicMCG(comptime T: type) T {
    return switch (T) {
        u32 => 0x93d765dd,
        u64 => 0xf1357aea2e62a9c5,
        u128 => 0xaadec8c3186345282b4e141f3a1232d5,
        else => @compileError("Size not supported"),
    };
}

pub fn harmonicLCG(comptime T: type) T {
    return switch (T) {
        u32 => 0x915f77f5,
        u64 => 0xd1342543de82ef95,
        u128 => 0xdb36357734e34abb0050d0761fcdfc15,
        else => @compileError("Size not supported"),
    };
}

pub const golden32 = 0x9e3779bd;
pub const golden64 = 0x9e3779b97f4a7c15;
pub const golden128 = 0x9e3779b97f4a7c15f39cc0605cedc835;
