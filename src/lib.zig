const std = @import("std");
const ArrayList = std.ArrayList;

pub fn UnsignedSized(comptime T: type) type {
    return std.meta.Int(.unsigned, @bitSizeOf(T));
}

pub const FloatSignType = u1;

pub fn FloatExponentType(comptime T: type) type {
    return switch (T) {
        f16 => u5,
        f32 => u8,
        f64 => u11,
        f80 => u15,
        f128 => u15,
        else => @compileError("Expects a float type"),
    };
}

pub fn floatExponentBits(comptime T: type) comptime_int {
    return switch (T) {
        f16 => 5,
        f32 => 8,
        f64 => 11,
        f80 => 15,
        f128 => 15,
        else => @compileError("Expects a float type"),
    };
}

pub fn floatExponentBias(comptime T: type) comptime_int {
    return (1 << floatExponentBits(T) - 1) - 1;
}

pub fn FloatFractionType(comptime T: type) type {
    return switch (T) {
        f16 => u10,
        f32 => u23,
        f64 => u52,
        f80 => u63,
        f128 => u112,
        else => @compileError("Expects a float type"),
    };
}

pub fn floatFractionBits(comptime T: type) comptime_int {
    return switch (T) {
        f16 => 10,
        f32 => 23,
        f64 => 52,
        f80 => 63,
        f128 => 112,
        else => @compileError("Expects a float type"),
    };
}

pub fn partsToFloat(
    comptime T: type,
    sign: FloatSignType,
    exponent: FloatExponentType(T),
    fraction: FloatFractionType(T),
) T {
    const signExponent = @as(UnsignedSized(T), sign) << floatExponentBits(T) | exponent;
    return @bitCast(T, signExponent << floatFractionBits(T) | fraction);
}

pub fn partsToF16(sign: u1, exponent: u5, fraction: u10) f16 {
    const signExponent = @as(u16, sign) << floatExponentBits(f16) | exponent;
    return @bitCast(f16, signExponent << floatFractionBits(f16) | fraction);
}

pub fn timeMicro() i128 {
    return @divTrunc(std.time.nanoTimestamp(), 1000);
}

/// Returns unsigned int T with phi fraction(.618...).
pub fn phiFraction(comptime T: type) T {
    std.debug.assert(@typeInfo(T).Int.signedness == .unsigned);

    // φ = (sqrt(5) - 1)/2 = (sqrt(2^(2^n) * 5) - 2^n)/2^n
    const bits = @bitSizeOf(T);
    const one = @as(std.meta.Int(.unsigned, bits * 2 + 3), 1) << bits;
    return @intCast(T, std.math.sqrt((one << bits) * 5) - one >> 1);
}

pub const MatrixError = error{ MatrixIncompatibleSizes, MatrixCopyOOB };

pub const MatrixF64 = struct {
    data: [][]f64,

    pub fn init(i: usize, t: usize) Self {
        return Self{ .data = [1][]f64{[1]f64{0} ** t} ** i };
    }

    pub fn copyIntoSelf(self: *Self, other: *Self, i: usize, t: usize) MatrixError!void {
        if (self.data.len < other.data.len + i or self.data[0].len < other.data[0] + t) {
            return .MatrixCopyOOB;
        }
        var indexI: usize = 0;
        while (indexI < other.data.len) {
            defer indexI += 1;
            var indexT: usize = 0;
            while (indexT < other.data[0].len) {
                defer indexT += 1;
                self.data[i + indexI][t + indexT] = other.data[i][t];
            }
        }
    }

    pub fn add(self: *Self, other: *Self) MatrixError!Self {
        if (self.data.len != other.data.len or self.data[0].len != other.data[0].len) {
            return .MatrixIncompatibleSizes;
        }
        var result = [self.data.len][self.data[0].len]f64{};
        var i: usize = 0;
        while (i < self.data.len) {
            defer i += 1;
            var t: usize = 0;
            while (t < self.data[0].len) {
                defer t += 1;
                result[i][t] = self.data[i][t] + other.data[i][t];
            }
        }
        return Self{ .data = result };
    }
    pub fn multiply(self: *Self, other: *Self) MatrixError!Self {
        if (self.data.len != other.data[0].len) {
            return .MatrixIncompatibleSizes;
        }
        var result = [self.data.len][other.data[0].len]f64{};
        var i: usize = 0;
        while (i < self.data.len) {
            defer i += 1;
            var t: usize = 0;
            while (t < other.data[0].len) {
                defer t += 1;
                var value: f64 = self.data[i][0] * other.data[0][t];
                var n: usize = 1;
                while (n < other.data.len) {
                    defer n += 1;
                    value += self.data[i][n] * other.data[n][t];
                }
                result[i][t] = value;
            }
        }
        return Self{ .data = result };
    }

    const Self = @This();
};
