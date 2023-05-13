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

pub fn shl(value: anytype, amount: anytype) @TypeOf(value) {
    return value << @intCast(ShiftType(@TypeOf(value)), amount);
}

pub fn shr(value: anytype, amount: anytype) @TypeOf(value) {
    return value >> @intCast(ShiftType(@TypeOf(value)), amount);
}

/// Bit rotate left, better asm support than `ror`.
pub fn rol(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @intCast(ShiftType(@TypeOf(value)), amount);
    return value << a | value >> -%a;
}

/// Bit rotate right, `rol` has better asm support.
pub fn ror(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @intCast(ShiftType(@TypeOf(value)), amount);
    return value >> a | value >> -%a;
}

pub fn shlOverflow(value: anytype, amount: anytype) @TypeOf(value) {
    return value << @truncate(ShiftType(@TypeOf(value)), amount);
}

pub fn shrOverflow(value: anytype, amount: anytype) @TypeOf(value) {
    return value >> @truncate(ShiftType(@TypeOf(value)), amount);
}

/// Bit rotate left, better asm support than `ror`.
pub fn rolOverflow(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @truncate(ShiftType(@TypeOf(value)), amount);
    return value << a | value >> -%a;
}

/// Bit rotate right, `rol` has better asm support.
pub fn rorOverflow(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @truncate(ShiftType(@TypeOf(value)), amount);
    return value >> a | value >> -%a;
}

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
