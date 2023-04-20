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
    comptime maxOrder: usize,
    comptime threshold: f64,
    runCount: usize,
    config: RNG.Config,
    alloc: Allocator,
) !Score {
    if (maxOrder < 10) return Score{ .order = 0, .fault = math.inf_f64 };

    var activeOrders = maxOrder - 9;
    var ordersTally = try alloc.alloc(Tally, activeOrders);
    for (ordersTally) |*tally| tally.* = try Tally.init(runCount, alloc);
    var run: usize = 0;
    runLoop: while (run < runCount) {
        defer run += 1;
        var tester = try TestDriver(RNG).init(@truncate(RNG.State, run), config, alloc);
        defer tester.deinit();
        for (ordersTally[0..activeOrders]) |*tally, order| {
            var subTests = try tester.next();
            for (subTests.iterator()) |pair| {
                if (tally.putAndReport(pair.key_ptr.*, pair.value_ptr.*, runCount) >= threshold) {
                    activeOrders = order;
                    continue :runLoop;
                }
            }
        }
    }
    if (activeOrders == 0) return Score{ .order = 0, .fault = math.inf_f64 };
    var faultSum: f64 = ordersTally[0].conclude();
    for (ordersTally[1..activeOrders]) |*tally, order| {
        const value = tally.conclude();
        if (faultSum + value >= threshold) {
            return Score{ .order = order + 9, .fault = faultSum };
        }
        faultSum += value;
    }
    return Score{ .order = activeOrders + 9, .fault = faultSum };
}

const Tally = struct {
    map: ManagedStringHashMap(TallyData),
    runs: usize,

    pub fn init(runs: usize, alloc: Allocator) !Self {
        return Self{ .map = ManagedStringHashMap(TallyData).init(alloc), .runs = runs };
    }

    pub fn putAndReport(self: *Self, name: []const u8, result: f64, count: usize) f64 {
        if (!self.map.contains(name)) {
            try self.map.put(name, try TallyData.init(count, self.map.allocator()));
        }
        return self.map.get(name).?.putReport(result);
    }

    pub fn conclude(self: *Self) f64 {
        defer self.map.deinit();
        var worstResult: f64 = 0.0;
        for (self.map.iterator()) |data| {
            const value = data.conclude(self.map.allocator());
            if (worstResult < value) worstResult = value;
        }
        return worstResult;
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

const TallyData = struct {
    results: []f64,
    negIndex: usize,

    posIndex: usize = 0,

    pub fn init(count: usize, alloc: Allocator) !Self {
        const results = try alloc.alloc(f64, count);
        mem.set(f64, results, 0.5);
        return Self{ .results = results, .negIndex = count };
    }

    pub fn putReport(self: *Self, value: f64) f64 {
        if (value < 0.0) {
            self.negIndex -= 1;
            self.results[self.negIndex] = -value;
        }
        self.results[self.posIndex] = value;
        self.posIndex += 1;
        return self.report();
    }

    pub fn conclude(self: *Self, alloc: Allocator) f64 {
        defer alloc.free(self.results);
        return self.report();
    }

    // -------------------------------- Internal --------------------------------

    fn report(self: *Self) f64 {
        const countPos = self.posIndex;
        const countNeg = self.results.len - self.negIndex;
        const averagePos = Self.sliceMuliplySum(self.results[0..countPos], 1 / countPos);
        const averageNeg = Self.sliceMuliplySum(self.results[self.negIndex..], 1 / countNeg);

        var average = @intToFloat(f64, self.results.len - countPos - countNeg) * 0.5;
        if (averageNeg / countNeg < averagePos / countPos) {
            average += (1 - averagePos) * countPos;
            average += averageNeg * countNeg;
        } else {
            average += averagePos * countPos;
            average += (1 - averageNeg) * countNeg;
        }
        average /= self.results.len; // TODO: divide earlier

        if (average > 0.5) std.debug.print("AVERAGE: {}({})", .{ average, self.results });
        const biased = 1 / average;
        return biased - 2;
    }

    fn sliceMuliplySum(slice: []f64, value: f64) f64 {
        var result: f64 = 0.0;
        for (slice) |v| result += v * value;
        return result;
    }

    const Self = @This();
};

pub fn fault(result: f64) f64 {
    if (result == math.nan_f64) return math.inf_f64;
    const value = @fabs(result); // best = 0.5, worst = 0
    const biased = 1 / value; //    best = 2.0, worst = inf
    return biased - 2; //           best = 0.0, worst = inf
}

pub fn worst(tests: SubTests, alloc: Allocator) !SubTest { // TODO: delete?
    var iter = tests.iterator();
    var result = iter.next() orelse unreachable;
    while (true) {
        const pair = iter.next() orelse break;
        if (@fabs(pair.value_ptr.*) < @fabs(result.value_ptr.*)) result = pair;
    }
    return SubTest.init(result.key_ptr.*, result.value_ptr.*, alloc);
}

// pub fn testRNG(
//     comptime RNG: type,
//     comptime maxOrder: usize,
//     comptime threshold: f64,
//     config: RNG.Config,
//     allocator: Allocator,
// ) !Score {
//     if (maxOrder < 10) return Score{ .order = 0, .fault = math.inf_f64 };

//     var driver = try TestDriver(RNG).init(0, config, allocator);
//     defer driver.deinit();
//     var sum = 1 / @fabs((try driver.reportWorst()).result);
//     if (sum >= threshold) return Score{ .order = 10, .fault = sum };
//     var o: usize = 11;
//     while (o < maxOrder) {
//         defer o += 1;
//         const fault = 1 / @fabs((try driver.reportWorst()).result);
//         if (sum + fault >= threshold) {
//             break;
//         } else sum += fault;
//     }
//     return Score{ .order = o - 1, .fault = sum };
// }

fn TestDriver(comptime RNG: type) type {
    return struct {
        rng: RNG,
        tester: std.ChildProcess,
        reader: std.fs.File.Reader,
        writer: std.fs.File.Writer,
        readBuffer: []u8,
        writeBuffer: []RNG.Out,

        readIndex: u16 = 0,
        writeReady: bool = false,
        subTests: SubTests = undefined,

        pub fn init(seed: RNG.State, config: RNG.Config, alloc: Allocator) !Self {
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
            }, alloc);
            tester.stdin_behavior = .Pipe;
            tester.stdout_behavior = .Pipe;
            try tester.spawn();
            _ = try os.fcntl(tester.stdin.?.handle, os.F.SETFL, os.O.NONBLOCK);
            _ = try os.fcntl(tester.stdout.?.handle, os.F.SETFL, os.O.NONBLOCK);

            return Self{
                .rng = RNG.init(seed, config),
                .tester = tester,
                .reader = tester.stdout.?.reader(),
                .writer = tester.stdin.?.writer(),
                .readBuffer = try tester.allocator.alloc(u8, 1 << 20),
                .writeBuffer = try tester.allocator.alloc(RNG.Out, 1 << 10),
            };
        }

        pub fn next(self: *Self) !SubTests {
            self.subTests = SubTests.init(self.tester.allocator);
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

        pub fn deinit(self: *Self) void {
            _ = self.tester.kill() catch unreachable;
        }

        // -------------------------------- Internal --------------------------------

        fn read(self: *Self) !bool {
            var readCount = self.reader.read(self.readBuffer[self.readIndex..]) catch 0;
            if (readCount == 0) return true;
            const readLen = self.readIndex + @intCast(u16, readCount);
            var lineStart: u16 = 0;

            // Parse readBuffer
            while (self.readIndex < readLen) {
                defer self.readIndex += 1;
                if (self.readBuffer[self.readIndex] != '\n') {
                    continue;
                }
                if (try self.parseLine(self.readBuffer[lineStart..self.readIndex])) return false;
                lineStart = self.readIndex + 1;
            }

            // Make space
            mem.copy(u8, self.readBuffer[0..], self.readBuffer[lineStart..readLen]);
            self.readIndex -= lineStart;
            // std.debug.print("{s}\n", .{self.readBuffer[0..self.readIndex]});
            return true;
        }

        fn parseLine(self: *Self, line: []const u8) !bool {
            // If line is empty
            if (line.len == 0) return self.subTests.count() > 0;

            // Ignore if un-indented or table header
            if (!mem.eql(u8, line[0..2], "  ") or mem.eql(u8, line[2..11], "Test Name")) {
                return false;
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
                    try self.subTests.put(testName, value);
                    return false;
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
                try self.subTests.put(testName, math.nan_f64);
                return false;
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
                try self.subTests.put(testName, value);
                return false;
            }

            // If p == normal value: "0.188"
            if (nonDigitChar == '.') {
                var value = trailingNumber * math.pow(f64, 10, -trailingDigitCount);
                if (value >= 0.5) value -= 1.0;
                try self.subTests.put(testName, value);
                return false;
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
            try self.subTests.put(testName, value);
            return false;
        }

        const Self = @This();
    };
}

pub const Score = struct {
    order: usize,
    fault: f64,

    pub fn worseThan(a: Score, b: Score) bool {
        if (a.order == b.order) return a.fault > b.fault;
        return a.order < b.order;
    }
};

pub const SubTests = ManagedStringHashMap(f64);

pub fn ManagedStringHashMap(comptime T: type) type {
    return struct {
        map: StringHashMap(T),

        pub fn init(alloc: Allocator) Self {
            return Self{ .map = StringHashMap(T).init(alloc) };
        }

        pub fn allocator(self: *Self) Allocator {
            return self.map.allocator;
        }

        pub fn put(self: *Self, key: []const u8, value: T) !void {
            if (self.map.contains(key)) {
                self.map.putAssumeCapacity(key, value);
                return;
            }
            try self.map.putNoClobber(try self.map.allocator.dupe(u8, key), value);
        }

        pub fn get(self: *Self, name: []const u8) ?T {
            return self.map.get(name);
        }

        pub fn count(self: *Self) StringHashMap(T).Size {
            return self.map.count();
        }

        pub fn iterator(self: *Self) Iterator {
            return self.map.iterator();
        }

        pub fn deinit(self: *Self) void {
            defer self.map.deinit();
            for (self.map.keyIterator()) |key| {
                self.map.allocator.free(key);
            }
        }

        pub const Iterator = StringHashMap(T).Iterator;

        // -------------------------------- Internal --------------------------------

        const Self = @This();
    };
}

pub const SubTest = struct {
    name: []const u8,
    result: f64,
    alloc: Allocator,

    pub fn init(name: []const u8, result: f64, alloc: Allocator) !Self {
        return Self{ .name = try alloc.dupe(u8, name), .result = result, .alloc = alloc };
    }

    pub fn deinit(self: *Self) void {
        self.alloc.free(self.name);
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

fn charToF64(char: u8) f64 {
    debug.assert(charIsDigit(char));
    return @intToFloat(f64, char - '0');
}

fn charIsDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}
