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

pub fn testRNG(
    comptime RNG: type,
    comptime orders: usize,
    comptime threshold: f64,
    // comptime runs: usize,
    config: RNG.Config,
    allocator: Allocator,
) !Score {
    if (orders == 0) return Score{ .order = 0, .fault = math.inf_f64 };

    var driver = try TestDriver(RNG).init(0, config, allocator);
    defer driver.deinit();
    var fault = 1 / @fabs((try driver.reportWorst()).result);
    if (fault >= threshold) return Score{ .order = 0, .fault = fault };
    var sum: f64 = 0;
    var o: usize = 1;
    while (o < orders) {
        defer o += 1;
        fault = 1 / @fabs((try driver.reportWorst()).result);
        // std.debug.print("o: {}\n", .{fault});
        if (sum + fault >= threshold) {
            break;
        } else sum += fault;
    }
    return Score{ .order = o - 1, .fault = sum };
}

fn TestDriver(comptime RNG: type) type {
    return struct {
        rng: RNG,
        tester: std.ChildProcess,
        reader: std.fs.File.Reader,
        writer: std.fs.File.Writer,
        readBuffer: []u8,
        writeBuffer: []RNG.Out,
        alloc: Allocator,

        readIndex: u16 = 0, // TODO: Refactor
        writeReady: bool = false,
        subTests: SubTests = undefined,

        pub fn init(testSeed: RNG.State, config: RNG.Config, allocator: Allocator) !Self {
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
            }, allocator);
            tester.stdin_behavior = .Pipe;
            tester.stdout_behavior = .Pipe;
            try tester.spawn();
            _ = try os.fcntl(tester.stdin.?.handle, os.F.SETFL, os.O.NONBLOCK);
            _ = try os.fcntl(tester.stdout.?.handle, os.F.SETFL, os.O.NONBLOCK);

            return Self{
                .rng = RNG.init(testSeed, config),
                .tester = tester,
                .reader = tester.stdout.?.reader(),
                .writer = tester.stdin.?.writer(),
                .readBuffer = try allocator.alloc(u8, 1 << 20),
                .writeBuffer = try allocator.alloc(RNG.Out, 1 << 10),
                .alloc = allocator,
            };
        }

        pub fn reportWorst(self: *Self) !SubTest {
            // defer self.subTests.deinit();
            var iter = (try self.reportAll()).iterator();
            var worst = iter.next() orelse unreachable;
            while (true) {
                const pair = iter.next() orelse break;
                if (@fabs(pair.value_ptr.*) < @fabs(worst.value_ptr.*)) worst = pair;
            }
            return SubTest{ .name = try self.alloc.dupe(u8, worst.key_ptr.*), .result = worst.value_ptr.* };
        }

        pub fn reportAll(self: *Self) !SubTests {
            self.subTests = SubTests.init(self.alloc);
            while (try self.read()) {
                if (!self.writeReady) for (self.writeBuffer) |*w| {
                    w.* = self.rng.gen();
                };
                self.writeReady = false;
                self.writer.writeAll(mem.sliceAsBytes(self.writeBuffer)) catch {
                    self.writeReady = true;
                };
            }
            return self.subTests;
        }

        fn read(self: *Self) !bool {
            var readCount = self.reader.read(self.readBuffer[self.readIndex..]) catch 0;
            if (readCount == 0) return true;
            const readLen = self.readIndex + @intCast(u16, readCount);
            var lineStart: u16 = 0;

            // Parse readBuffer
            while (self.readIndex < readLen) {
                var lineRead = true;
                defer {
                    self.readIndex += 1;
                    if (lineRead) lineStart = self.readIndex;
                }
                // If line not done
                if (self.readBuffer[self.readIndex] != '\n') {
                    lineRead = false;
                    continue;
                }
                const line = self.readBuffer[lineStart..self.readIndex];

                // If line is empty
                if (line.len == 0) {
                    if (self.subTests.count() == 0) continue;
                    self.readIndex += 1;
                    if (lineRead) lineStart = self.readIndex; // TODO: Refactor
                    return false;
                }

                // Ignore if un-indented or table header
                if (!mem.eql(u8, line[0..2], "  ") or mem.eql(u8, line[2..11], "Test Name")) {
                    continue;
                }

                // Skip indentation
                var l: usize = 2;

                // Find test name
                while (line[l] != ' ') l += 1;
                const testName = line[2..l];

                // Find 'p'
                while (line[l] != 'p') {
                    defer l += 1;

                    // When instead of 'p' there is "fail" or "pass"
                    if (line[l] == '"') {
                        const value: f64 = if (line[l + 1] == 'f') 0 else 0.5;
                        try self.subTests.putNoClobber(try self.alloc.dupe(u8, testName), value);
                        continue;
                    }
                }

                // Jump after '='
                l += 3;

                // Find number start
                while (line[l] == ' ') l += 1;

                // Find number end
                while (line[l] != ' ') l += 1;
                const trailingChar = line[l - 1];

                // If p == "nan"
                if (trailingChar == 'n') {
                    try self.subTests.putNoClobber(try self.alloc.dupe(u8, testName), math.nan_f64);
                    continue;
                }

                var trailingNumber: f64 = charToF64(trailingChar);
                var trailingDigitCount: f64 = 1;

                // Skip ' ' and last digit
                l -= 2;
                var trailingNumberChar = line[l];

                // Fill trailingNumber
                while (charIsDigit(trailingNumberChar)) {
                    const exp = math.pow(f64, 10, trailingDigitCount);
                    trailingNumber += charToF64(trailingNumberChar) * exp;
                    trailingDigitCount += 1;
                    l -= 1;
                    trailingNumberChar = line[l];
                }

                const nonDigitIndex = l;
                const nonDigitChar = line[nonDigitIndex];

                // If p == '0' or '1'
                if (nonDigitChar == ' ') {
                    const value = if (trailingNumber == 1) @as(f64, -0.0) else @as(f64, 0.0);
                    try self.subTests.putNoClobber(try self.alloc.dupe(u8, testName), value);
                    continue;
                }

                // If p == normal value: "0.188"
                if (nonDigitChar == '.') {
                    var value = trailingNumber * math.pow(f64, 10, -trailingDigitCount);
                    if (value >= 0.5) value -= 1.0;
                    try self.subTests.putNoClobber(try self.alloc.dupe(u8, testName), value);
                    continue;
                }

                // p must be in scientific notation
                var coefficient = charToF64(line[nonDigitIndex - 2]);
                var symbolIndex = nonDigitIndex - 3;

                // If coefficient has fraction: "2.3e-4" or "1-2.7e-3"
                if (line[symbolIndex] == '.') {
                    coefficient = charToF64(line[nonDigitIndex - 4]) + coefficient / 10;
                    symbolIndex -= 2;
                }

                var value = coefficient * math.pow(f64, 10, -trailingNumber);
                if (line[symbolIndex] == '-') value = -value;
                try self.subTests.putNoClobber(try self.alloc.dupe(u8, testName), value);
            }

            // Make space
            mem.copy(u8, self.readBuffer[0..], self.readBuffer[lineStart..readLen]);
            self.readIndex -= lineStart;
            return true;
        }

        pub fn deinit(self: *Self) void {
            _ = self.tester.kill() catch unreachable;
        }

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}

pub const Score = struct {
    order: usize,
    fault: f64,

    pub fn worseThan(a: Score, b: Score) bool {
        if (a.order == b.order) {
            return if (a.fault > b.fault) true else false;
        }
        return if (a.order < b.order) true else false;
    }

    // pub fn better(a: Score, b: Score) Score {
    //     if (a.order == b.order) {
    //         return if (a.fault < b.fault) a else b;
    //     }
    //     return if (a.order > b.order) a else b;
    // }
};

pub const SubTests = StringHashMap(f64);

pub const SubTest = struct {
    name: []const u8,
    result: f64,
};

fn charToF64(char: u8) f64 {
    debug.assert(charIsDigit(char));
    return @intToFloat(f64, char - '0');
}

fn charIsDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}
