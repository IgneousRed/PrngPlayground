const std = @import("std");

pub fn size(comptime T: type) comptime_int {
    return @bitSizeOf(T);
}

pub fn typeSize(comptime value: anytype) comptime_int {
    return @bitSizeOf(@TypeOf(value));
}

/// Returns unsigned type with size == `bits`
pub fn U(comptime bits: comptime_int) type {
    return std.meta.Int(.unsigned, bits);
}

/// Returns the right type for shifting T.
pub fn ShiftType(comptime T: type) type {
    return std.math.Log2Int(T);
}

/// Returns the right type for shifting T.
pub fn shiftSize(comptime bits: comptime_int) comptime_int {
    return std.math.log2(bits);
}

/// Casts value into right type for shifting T.
pub fn ShiftCast(comptime T: type, value: anytype) ShiftType(T) {
    return @intCast(ShiftType(T), value);
}

/// bit rotate right.
pub fn ror(comptime bits: comptime_int, source: U(bits), amount: ShiftType(bits)) U(bits) {
    return source >> amount | source << -%amount;
}

/// 8bit rotate right.
pub fn ror8(source: u8, amount: u3) u8 {
    return source >> amount | source << -%amount;
}

/// 16bit rotate right.
pub fn ror16(source: u16, amount: u4) u16 {
    return source >> amount | source << -%amount;
}

/// 32bit rotate right.
pub fn ror32(source: u32, amount: u5) u32 {
    return source >> amount | source << -%amount;
}

/// 64bit rotate right.
pub fn ror64(source: u64, amount: u6) u64 {
    return source >> amount | source << -%amount;
}

/// 128bit rotate right.
pub fn ror128(source: u128, amount: u7) u128 {
    return source >> amount | source << -%amount;
}

// pub fn split()

/// Returns the low bits of an int.
pub fn low(comptime T: type, int: anytype) T {
    return @truncate(T, int);
}

/// Returns the hign bits of an int.
pub fn high(comptime T: type, int: anytype) T {
    return @intCast(T, int >> @bitSizeOf(@TypeOf(int)) - @bitSizeOf(T));
}

pub fn concat(comptime T: type, highInt: anytype, lowInt: anytype) T {
    return @intCast(T, highInt) << @bitSizeOf(@TypeOf(lowInt)) | lowInt;
}
