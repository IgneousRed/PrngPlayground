const std = @import("std");
const Allocator = std.mem.Allocator;

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

/// StringHashMap where keys are managed.
pub fn ManagedStringHashMap(comptime T: type) type {
    return struct {
        map: std.StringHashMap(T),

        pub fn init(alloc: Allocator) Self {
            return Self{ .map = std.StringHashMap(T).init(alloc) };
        }

        pub fn allocator(self: *Self) Allocator {
            return self.map.allocator;
        }

        pub fn contains(self: *Self, name: []const u8) bool {
            return self.map.contains(name);
        }

        /// Puts `value` into map, dupes the key if not present.
        pub fn put(self: *Self, key: []const u8, value: T) !void {
            if (self.map.contains(key)) {
                self.map.putAssumeCapacity(key, value);
                return;
            }
            try self.map.putNoClobber(try self.map.allocator.dupe(u8, key), value);
        }

        pub fn getPtr(self: *Self, name: []const u8) ?*T {
            return self.map.getPtr(name);
        }

        pub fn count(self: *Self) std.StringHashMap(T).Size {
            return self.map.count();
        }

        pub fn iterator(self: *Self) Iterator {
            return self.map.iterator();
        }

        /// Frees both the map and all the keys.
        pub fn deinit(self: *Self) void {
            defer self.map.deinit();
            var iter = self.map.keyIterator();
            while (iter.next()) |key| {
                self.map.allocator.free(key.*);
            }
        }

        pub const Iterator = std.StringHashMap(T).Iterator;

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}

const NonBlockingLineReader = struct {
    reader: std.fs.File.Reader,
    buffer: []u8,
    read: usize = 0,
    lineStart: usize = 0,
    end: usize = 0,

    pub fn init(file: std.fs.File, bufferSize: usize, alloc: Allocator) !Self {
        _ = try std.os.fcntl(file.handle, std.os.F.SETFL, std.os.O.NONBLOCK);
        return .{ .reader = file.reader(), .buffer = try alloc.alloc(u8, bufferSize) };
    }

    pub fn line(self: *Self) ?[]const u8 {
        // If buffer has available
        const result = self.parse();
        if (result != null) return result;

        // If space could be freed
        if (self.lineStart > 0) {
            std.mem.copy(u8, self.buffer[0..], self.buffer[self.lineStart..self.end]);
            self.read -= self.lineStart;
            self.lineStart = 0;
            self.end = self.read;
        }

        // Fill buffer
        self.end = self.read + self.reader.read(self.buffer[self.read..]) catch 0;
        return self.parse();
    }

    // -------------------------------- Internal --------------------------------

    fn parse(self: *Self) ?[]const u8 {
        while (self.read < self.end) {
            defer self.read += 1;
            if (self.buffer[self.read] != '\n') continue;
            defer self.lineStart = self.read + 1;
            return self.buffer[self.lineStart..self.read];
        }
        return null;
    }

    const Self = @This();
};

pub fn factorial(value: usize) usize {
    var result: usize = 1;
    var i: usize = 2;
    while (i <= value) : (i += 1) result *= i;
    return result;
}

/// Returns `n`th permutation of `result.len` indexes
pub fn indexPermutation(result: []usize, n: usize) void {
    var perm = n;
    for (result) |*res, r| {
        const rOpposite = result.len - r;
        var pick = perm % rOpposite;
        var i: usize = 0;
        while (i <= pick) : (i += 1) for (result[0..r]) |v| if (v == i) {
            pick += 1;
            continue;
        };
        res.* = pick;
        perm /= rOpposite;
    }
}

pub fn nano64() u64 {
    return @truncate(u64, @intCast(u128, std.time.nanoTimestamp()));
}

pub fn mulInv(value: anytype) @TypeOf(value) {
    const T = @TypeOf(value);
    const Info = @typeInfo(T);
    if (Info != .Int) @compileError("Expects unsigned int");
    if (Info.Int.signedness != .unsigned) @compileError("Expects unsigned int");

    var result = value *% 3 ^ 2;
    var temp = 1 -% result *% value;
    comptime var b = 10;
    inline while (b < @bitSizeOf(T)) : (b *= 2) {
        result *%= temp +% 1;
        temp *%= temp;
    }
    return result *% (temp +% 1);
}
pub fn xshrInv(comptime n: comptime_int, value: anytype) @TypeOf(value) {
    const T = @TypeOf(value);
    const Info = @typeInfo(T);
    if (Info != .Int) @compileError("Expects unsigned int");
    if (Info.Int.signedness != .unsigned) @compileError("Expects unsigned int");

    var result = value;
    comptime var b = n;
    inline while (b < @bitSizeOf(T)) : (b *= 2) {
        result ^= result >> b;
    }
    return result;
}
pub fn xshlInv(comptime n: comptime_int, value: anytype) @TypeOf(value) {
    const T = @TypeOf(value);
    const Info = @typeInfo(T);
    if (Info != .Int) @compileError("Expects unsigned int");
    if (Info.Int.signedness != .unsigned) @compileError("Expects unsigned int");

    var result = value;
    comptime var b = n;
    inline while (b < @bitSizeOf(T)) : (b *= 2) {
        result ^= result << b;
    }
    return result;
}
