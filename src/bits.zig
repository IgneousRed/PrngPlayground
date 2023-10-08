const std = @import("std");

pub fn usizeToF64(val: usize) f64 {
    return @floatFromInt(val);
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
    return @intCast(value);
}

pub fn shl(value: anytype, amount: anytype) @TypeOf(value) {
    var temp: ShiftType(@TypeOf(value)) = @truncate(amount);
    return value << temp;
}

pub fn shr(value: anytype, amount: anytype) @TypeOf(value) {
    return value >> @as(ShiftType(@TypeOf(value)), @truncate(amount));
}

/// Bit rotate left, `ror` has better asm support.
pub fn rol(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @as(ShiftType(@TypeOf(value)), @truncate(amount));
    return value << a | value >> -%a;
}

/// Bit rotate right, better asm support than `rol`.
pub fn ror(value: anytype, amount: anytype) @TypeOf(value) {
    const a = @as(ShiftType(@TypeOf(value)), @truncate(amount));
    return value >> a | value << -%a;
}

/// Returns the low bits of an int.
pub fn low(comptime T: type, int: anytype) T {
    return @as(T, @truncate(int));
}

/// Returns the hign bits of an int.
pub fn high(comptime T: type, int: anytype) T {
    return @as(T, @intCast(int >> @bitSizeOf(@TypeOf(int)) - @bitSizeOf(T)));
}

pub fn multiplyFull(a: anytype, b: @TypeOf(a)) U(@bitSizeOf(@TypeOf(a)) * 2) {
    return @as(U(@bitSizeOf(@TypeOf(a)) * 2), a) * b;
}

pub fn Half(comptime T: type) type {
    const size = @bitSizeOf(T);
    if (size % 2 != 0) @compileError("Type bit size must be even");
    return U(size / 2);
}

pub fn SplitHalf(comptime T: type) type {
    const I = Half(T);
    return struct { high: I, low: I };
}

pub fn splitHalf(comptime T: type, int: T) SplitHalf(T) {
    const I = U(@bitSizeOf(@TypeOf(int)) / 2);
    return .{ .high = high(I, int), .low = low(I, int) };
}

pub fn concat(highInt: anytype, lowInt: anytype) U(@bitSizeOf(@TypeOf(highInt)) + @bitSizeOf(@TypeOf(lowInt))) {
    const lowBits = @bitSizeOf(@TypeOf(lowInt));
    return @as(U(@bitSizeOf(@TypeOf(highInt)) + lowBits), @intCast(highInt)) << lowBits | lowInt;
}

// pub fn Concat(a: anytype, b: anytype) type {
//     const A = @TypeOf(a);
//     const B = @TypeOf(b);
//     const AI = @typeInfo(A);
//     const BI = @typeInfo(B);
//     if (AI != .Int) @compileError("Concat only works with ints");
//     if (BI != .Int) @compileError("Concat only works with ints");
//     if (AI.Int.signedness != BI.Int.signedness) @compileError("Ints must have same signedness");
//     return std.meta.Int(AI.Int.signedness, @bitSizeOf(A) + @bitSizeOf(B));
// }

// pub fn concat(highInt: anytype, lowInt: anytype) Concat(highInt, lowInt) {
//     return @intCast(Concat(highInt, lowInt), highInt) << @bitSizeOf(@TypeOf(lowInt)) | low;
// }
