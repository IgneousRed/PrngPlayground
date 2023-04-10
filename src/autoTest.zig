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

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

pub fn collapseRuns(
    comptime orders: u6,
    comptime runs: usize,
    results: TestResults(orders, runs), // [orders]StringHashMap([runs]f64)
) TestResult(orders) {
    var result: TestResult(orders) = undefined;
    for (results) |v, i| {
        result[i] = StringHashMap(f64).init(alloc);
        var iter = v.iterator();
        while (true) {
            const pair = iter.next() orelse break;
            v
        }
    }
    return result;
}

pub fn testPRNG(
    comptime prng: type,
    comptime orders: u6,
    comptime runs: usize,
) !TestResults(orders, runs) {
    _ = prng;
    var asd = try ASD(orders, runs).init(alloc);
    var i = runs;
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

fn ASD(comptime orders: u6, comptime runs: usize) type {
    return struct {

        writeBuffer: [1 << 10]u64, // TODO: Size
        writeDone: bool,
        writeState: u64, // TODO: Type
        writer: std.fs.File.Writer,

        parser: TestParser(orders, runs),

        pub fn init() !Self {
            return Self{
                .writeBuffer = undefined,
                .writeDone = true,
                .writeState = undefined,
                .writer = undefined,
                .parser = TestParser(orders, runs).init(),
            };
        }

        pub fn run(self: *Self, i: usize) !void {
            _ = i;
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
            _ = try os.fcntl(tester.stdin.?.handle, os.F.SETFL, os.O.NONBLOCK);
            _ = try os.fcntl(tester.stdout.?.handle, os.F.SETFL, os.O.NONBLOCK);

            self.parser.setup(tester.stdout.?.reader());
            self.writer = tester.stdin.?.writer();
            self.writeState = 0;

            while (try self.parser.read()) {
                self.write();
            }
            _ = try tester.kill();
        }

        pub fn done(self: *Self) !TestResults(orders, runs) {
            return self.parser.done();
        }

        // -------------------------------- Internal --------------------------------

        fn write(self: *Self) void {
            if (self.writeDone) {
                for (self.writeBuffer) |_, w| {
                    var value = self.writeState;
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
                    self.writeBuffer[w] = value;
                    self.writeState += 1;
                }
            }
            self.writeDone = true;
            self.writer.writeAll(mem.asBytes(self.writeBuffer[0..])) catch {
                self.writeDone = false;
            };
        }

        const Self = @This();
    };
}

fn TestParser(comptime orders: u6, comptime runs: usize) type {
    return struct {
        tallyArr: [orders]Tally(runs),
        tallyIndex: usize,
        tally: *Tally(runs),
        readBuffer: [1 << 16]u8,
        readIndex: u16,
        reader: std.fs.File.Reader,

        pub fn init() Self {
            var arr: [orders]Tally(runs) = undefined;
            for (arr) |_, i| {
                arr[i] = Tally(runs).init();
            }
            return Self{
                .tallyArr = arr,
                .tallyIndex = undefined,
                .tally = undefined,
                .readBuffer = undefined,
                .readIndex = undefined,
                .reader = undefined,
            };
        }

        pub fn setup(self: *Self, reader: std.fs.File.Reader) void {
            self.tallyIndex = -%@as(usize, 1);
            self.readIndex = 0;
            self.reader = reader;
        }

        pub fn read(self: *Self) !bool {
            // Fill self.readBuffer
            var readCount = self.reader.read(self.readBuffer[self.readIndex..]) catch 0;
            if (readCount == 0) return true;
            const readLen = self.readIndex + @intCast(u16, readCount);
            var lineStart: u16 = 0;

            // Parse self.readBuffer
            while (true) {
                if (self.readBuffer[self.readIndex] == '\n') {
                    if (try self.anyLine(self.readBuffer[lineStart..self.readIndex])) return false;
                    lineStart = self.readIndex + 1;
                }
                self.readIndex += 1;
                if (self.readIndex == readLen) break;
            }

            // Make space
            mem.copy(u8, self.readBuffer[0..], self.readBuffer[lineStart..readLen]);
            self.readIndex -= lineStart;
            return true;
        }

        pub fn done(self: *Self) !Results {
            const time = @truncate(u64, @intCast(u128, std.time.nanoTimestamp()));
            var rng = rand.DefaultPrng.init(time);
            var result: Results = undefined;
            for (self.tallyArr) |*t, i| result[i] = try t.done(rng.random());
            return result;
        }

        // -------------------------------- Internal --------------------------------

        /// Updates the tallyIndex and tallies results
        fn anyLine(self: *Self, line: []const u8) !bool {
            // If line empty
            if (line.len == 0) return if (self.tallyIndex +% 1 == self.tallyArr.len) true else false;

            // If declaring order of magnitude
            if (mem.eql(u8, line[0..6], "length")) {
                var i: usize = 6;
                while (line[i] != '^') i += 1;

                // -10 as it starts from 10
                self.tallyIndex = charToUsize(line[i + 1]) * 10 + charToUsize(line[i + 2]) - 10;
                self.tally = &self.tallyArr[self.tallyIndex];
                return false;
            }

            // Ignore if un-indented or table header
            if (!mem.eql(u8, line[0..2], "  ") or mem.eql(u8, line[2..11], "Test Name")) return false;

            // Process the actual test result
            try self.tallyResult(line[2..]);
            return false;
        }

        /// Tallies the folded result, meaning both 0 and 1 will be 0
        fn tallyResult(self: *Self, line: []const u8) !void {
            var i: usize = 0;

            // Find test name
            while (line[i] != ' ') i += 1;
            const testName = line[0..i];

            // Find 'p'
            while (line[i] != 'p') {
                defer i += 1;

                // When instead of 'p' there is "fail" or "pass"
                if (line[i] == '"') {
                    const value: f64 = if (line[i + 1] == 'p') 1 else 0;
                    return try self.tally.note(testName, value);
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
                return try self.tally.note(testName, 0.0);
            }

            // If p == normal value: "0.188"
            if (nonDigitChar == '.') {
                return try self.tally.note(
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

            return try self.tally.note(
                testName,
                fold(coefficient * math.pow(f64, 10, -trailingNumber)),
            );
        }

        const Results = TestResults(orders, runs);
        const Self = @This();
    };
}

pub fn TestResults(comptime orders: u6, comptime runs: usize) type {
    return [orders]StringHashMap([runs]f64);
}

pub fn TestResult(comptime orders: u6) type {
    return [orders]StringHashMap(f64);
}

/// Talies results from multiple test runs.
fn Tally(comptime runs: usize) type {
    return struct {
        map: StringHashMap(Array),

        pub fn init() Self {
            return Self{
                .map = StringHashMap(Array).init(alloc),
            };
        }

        /// Tallies the test.
        pub fn note(self: *Self, name: []const u8, result: f64) !void {
            if (!self.map.contains(name)) {
                const dupe = try alloc.dupe(u8, name);
                try self.map.putNoClobber(dupe, Array.init(0) catch unreachable);
            }
            self.map.getPtr(name).?.appendAssumeCapacity(result);
        }

        pub fn done(self: *Self, rng: Random) !StringHashMap([runs]f64) { // TODO: Slice > HashMap?
            defer self.map.deinit();
            var result = StringHashMap([runs]f64).init(alloc);
            var iter = self.map.iterator();
            while (true) {
                const pair = iter.next() orelse break;
                if (pair.value_ptr.len < runs) {
                    while (pair.value_ptr.len < runs) {
                        pair.value_ptr.appendAssumeCapacity(1);
                    }
                    rng.shuffle(f64, &pair.value_ptr.buffer);
                }
                try result.putNoClobber(pair.key_ptr.*, pair.value_ptr.buffer);
            }
            return result;
        }

        // -------------------------------- Internal --------------------------------

        const Array = BoundedArray(f64, runs);
        const Self = @This();
    };
}
