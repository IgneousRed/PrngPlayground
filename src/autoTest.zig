const std = @import("std");
const mem = std.mem;
const os = std.os;
const math = std.math;
const debug = std.debug;
const dev = @import("prng_dev.zig");
const StringHashMap = std.StringHashMap;
const Allocator = mem.Allocator;
const BoundedArray = std.BoundedArray;
const rand = std.rand;
const Random = rand.Random;

pub fn testPRNG(
    comptime prng: type,
    allocator: Allocator,
    orders: u6,
    tries: usize,
) ![]StringHashMap(Tally.Data) {
    _ = prng;
    var asd = try ASD.init(allocator, orders, tries);
    var i = tries;
    while (i > 0) {
        defer i -= 1;
        try asd.run(i);
    }
    return try asd.done();
}

fn charIsDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn charToUsize(char: u8) usize {
    debug.assert(charIsDigit(char));
    return @intCast(usize, char - '0');
}

fn charToF64(char: u8) f64 {
    debug.assert(charIsDigit(char));
    return @intToFloat(f64, char - '0');
}

fn fold(value: f64) f64 {
    return 1 - @fabs(value * 2 - 1);
}

const ASD = struct {
    alloc: Allocator,
    tallySlice: []Tally,
    tallyIndex: usize,

    pub fn init(allocator: Allocator, orders: u6, tries: usize) !Self {
        const slice = try allocator.alloc(Tally, orders);
        for (slice) |_, i| {
            slice[i] = Tally.init(allocator, tries);
        }
        return Self{
            .alloc = allocator,
            .tallySlice = slice,
            .tallyIndex = -%@as(usize, 1),
        };
    }

    pub fn run(self: *Self, i: usize) !void {
        var tester = std.ChildProcess.init(&[_][]const u8{
            "/Users/gio/PractRand/RNG_test",
            "stdin",
            "-a",
            "-tf",
            "2",
            "-te",
            "1",
            "-tlmin",
            "10",
            "-tlmax",
            "99",
            "-tlmaxonly",
            "-multithreaded",
        }, self.alloc);
        tester.stdin_behavior = .Pipe;
        tester.stdout_behavior = .Pipe;
        try tester.spawn();
        const testerIn = tester.stdin.?.writer();
        const testerOut = tester.stdout.?.reader();
        _ = try os.fcntl(tester.stdin.?.handle, os.F.SETFL, os.O.NONBLOCK);
        _ = try os.fcntl(tester.stdout.?.handle, os.F.SETFL, os.O.NONBLOCK);

        var readIndex: u16 = 0;
        var readBuffer = [1]u8{0} ** (1 << 16); // TODO: Increase
        var writeBuffer = [1]u64{0} ** (1 << 10); // TODO: Increase?
        var state: u64 = i *% dev.oddPhiFraction(u64);

        // Fill result
        writeReadLoop: while (true) {
            // Write
            for (writeBuffer) |_, w| {
                var value = state;
                value ^= value >> 36;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 24;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 36;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 24;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 36;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 24;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 36;
                value *%= dev.harmonic64MCG64;
                value ^= value >> 24;
                value *%= dev.harmonic64MCG64;
                writeBuffer[w] = value;
                state += 1;
            }
            testerIn.writeAll(mem.asBytes(writeBuffer[0..])) catch {};

            // Read
            var readCount = testerOut.read(readBuffer[readIndex..]) catch 0;
            if (readCount == 0) continue;
            const readLen = readIndex + @intCast(u16, readCount);
            var lineStart: u16 = 0;

            // Parse readBuffer
            while (true) {
                if (readBuffer[readIndex] == '\n') {
                    if (try self.anyLine(readBuffer[lineStart..readIndex])) break :writeReadLoop;
                    lineStart = readIndex + 1;
                }
                readIndex += 1;
                if (readIndex == readLen) break;
            }
            mem.copy(u8, readBuffer[0..], readBuffer[lineStart..readLen]);
            readIndex -= lineStart;
        }
    }

    pub fn done(self: *Self) ![]StringHashMap(Tally.Data) {
        defer self.alloc.free(self.tallySlice);
        const result = try self.alloc.alloc(StringHashMap(Tally.Data), self.tallySlice.len);
        for (self.tallySlice) |*t, i| {
            result[i] = t.conclude();
        }
        return result;
    }

    ////////////// Internal //////////////////

    const Self = @This();

    /// Updates the tallyIndex and tallies results
    fn anyLine(self: *Self, line: []const u8) !bool {
        // If line empty
        if (line.len == 0) return if (self.tallyIndex +% 1 == self.tallySlice.len) true else false;

        // Ignore if un-indented or table header
        if (!mem.eql(u8, line[0..2], "  ") or mem.eql(u8, line[2..11], "Test Name")) return false;

        // If declaring order of magnitude
        if (mem.eql(u8, line[0..6], "length")) {
            var i: usize = 6;
            while (line[i] != '^') i += 1;

            // -10 as it starts from 10
            self.tallyIndex = charToUsize(line[i + 1]) * 10 + charToUsize(line[i + 2]) - 10;
            return false;
        }

        // Process the actual test result
        try self.tallyResult(line[2..]);
        return false;
    }

    /// Tallies the folded result, meaning both 0 and 1 will be 0
    fn tallyResult(self: *Self, line: []const u8) !void {
        // Skip indentation
        var i: usize = 2;

        // Find test name
        while (line[i] != ' ') i += 1;
        const testName = line[2..i];

        // Find 'p'
        while (line[i] != 'p') {
            defer i += 1;

            // When instead of 'p' there is "fail" or "pass"
            if (line[i] == '"') {
                const value = if (line[i + 1] == 'p') 1 else 0;
                return try self.tallySlice[self.tallyIndex].note(testName, value);
            }
        }

        // Jump after '='
        i += 3;

        // Find number start
        while (line[i] == ' ') i += 1;

        // Find number end
        while (line[i] != ' ') i += 1;
        const numberEnd = i;

        var trailingNumber: f64 = charToF64(line[numberEnd - 1]);
        var trailingDigitCount: f64 = 1;

        // Skip ' ' and last digit
        var trailingNumberIndex = numberEnd - 2;
        var trailingNumberChar = line[trailingNumberIndex];

        // Fill trailingNumber
        while (charIsDigit(trailingNumberChar)) {
            trailingNumber += charToF64(trailingNumberChar) * math.pow(f64, 10, trailingDigitCount);
            trailingDigitCount += 1;
            trailingNumberIndex -= 1;
            trailingNumberChar = line[trailingNumberIndex];
        }

        const nonDigitIndex = trailingNumberIndex;
        const nonDigitChar = line[nonDigitIndex];

        // If p == '0' or '1'
        if (nonDigitChar == ' ') {
            return try self.tallySlice[self.tallyIndex].note(testName, 0.0);
        }

        // If p == normal value: "0.188"
        if (nonDigitChar == '.') {
            return try self.tallySlice[self.tallyIndex].note(
                testName,
                fold(trailingNumber * math.pow(f64, 10, -trailingDigitCount)),
            );
        }

        // p must be in scientific notation
        var coefficient = charToF64(line[nonDigitIndex - 2]);

        // If coefficient has fraction: "2.3e-4" or "1-2.7e-3"
        if (line[nonDigitIndex - 3] == '.') {
            coefficient = charToF64(line[nonDigitIndex - 4]) + coefficient / 10;
        }

        return try self.tallySlice[self.tallyIndex].note(
            testName,
            fold(coefficient * math.pow(f64, 10, -trailingNumber)),
        );
    }
};

/// Talies results from multiple test runs.
pub fn Tally(comptime runs: usize) type {
    return struct {
        map: StringHashMap(BoundedArray(f64, runs)),

        pub fn init(allocator: Allocator) Self {
            return Self{
                .map = StringHashMap(BoundedArray(f64, runs)).init(allocator),
            };
        }

        /// Tallies the test.
        pub fn note(self: *Self, name: []const u8, result: f64) !void {
            if (!self.map.contains(name)) {
                try self.map.putNoClobber(name, BoundedArray(f64, runs).init(0) catch unreachable);
            }
            self.map.getPtr(name).?.appendAssumeCapacity(result);
        }

        pub fn done(self: *Self, rng: Random) StringHashMap([runs]f64) { // TODO: Slice > HashMap?
            defer self.map.deinit(); // TODO: Free keys?
            const result = StringHashMap([runs]f64).init(self.map.allocator);
            var iter = self.map.iterator();
            while (true) {
                const pair = iter.next() orelse break;
                if (pair.value_ptr.len < runs) {
                    while (pair.value_ptr.len < runs) {
                        pair.value_ptr.appendAssumeCapacity(1);
                    }
                    rng.shuffle(f64, pair.value_ptr.buffer);
                }
                try result.put(pair.key_ptr.*, pair.value_ptr.buffer);
            }
            return result;
        }

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}
