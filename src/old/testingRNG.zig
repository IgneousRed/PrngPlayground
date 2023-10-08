const std = @import("std");
const dev = @import("rng_dev.zig");
const lib = @import("lib.zig");
const Allocator = std.mem.Allocator;

// TODO: Think about false positives and compare with default

const threshold = 1 << 33; // 8_589_934_592

pub fn configRNG(
    comptime RNG: type,
    comptime maxOrder: u6,
    round: u5,
    details: bool,
    runForever: bool,
    alloc: Allocator,
) !void {
    var config = RNG.bestKnown;
    var roundCurrent = round;
    while (true) {
        defer roundCurrent += 1;
        const header = .{ roundCurrent, maxOrder, @typeName(RNG), config };
        std.debug.print("round: {}, maxOrder: {}, configuring: {s}, bestKnown: {any}\n", header);
        const timeStart = std.time.timestamp();
        const runs = @as(usize, 1) << roundCurrent;
        var best = Score{};
        for (config) |*conf, c| {
            var bestI: usize = if (c == 0) -%@as(usize, 1) else conf.*;
            var i: usize = 0;
            while (i < RNG.configSize[c]) {
                defer i += 1;

                conf.* = i;
                const result = try testRNG(RNG, maxOrder, runs, config, alloc);

                const report = .{ RNG.configName[c], i, result.order, result.quality };
                if (details) std.debug.print("    {s}: {}, order: {}, quality: {d}\n", report);

                if (best.pack() <= result.pack()) {
                    best = result;
                    bestI = i;
                }
            }
            conf.* = bestI;

            const pick = .{ RNG.configName[c], bestI, best.order, best.quality };
            if (details) std.debug.print("  {s}: {}, order: {}, quality: {d}\n", pick);
        }
        std.debug.print("round: {}, config: {any}, order: {}, quality: {d}, runtime: {}s\n\n", .{
            roundCurrent,
            config,
            best.order,
            best.quality,
            std.time.timestamp() - timeStart,
        });
        if (!runForever) return;
    }
}

pub fn testRNG(
    comptime RNG: type,
    comptime maxOrder: u6,
    runCount: usize,
    config: RNG.Config,
    alloc: Allocator,
) !Score {
    if (maxOrder < 10) return .{};

    var activeOrders = maxOrder - 9;
    var ordersTally = try alloc.alloc(Tally, activeOrders);
    for (ordersTally) |*tally| tally.* = try Tally.init(runCount, alloc);
    var run: usize = 0;
    runLoop: while (run < runCount) {
        defer run += 1;
        var tester = try TestDriver(RNG).init(run, config, alloc);
        defer tester.deinit();
        for (ordersTally[0..activeOrders]) |*tally, order| {
            var subTests = try tester.next();
            var iter = subTests.iterator();
            while (iter.next()) |pair| {
                const report = try tally.putAndReport(pair.key_ptr.*, pair.value_ptr.*);
                if (report >= threshold) {
                    activeOrders = @intCast(u6, order);
                    continue :runLoop;
                }
            }
        }
    }
    if (activeOrders == 0) return .{};
    var faultSum: f64 = 0.0;
    for (ordersTally[0..activeOrders]) |*tally, order| { // TODO: merge the two for loops
        const value = tally.conclude();
        if (faultSum + value >= threshold) {
            activeOrders = @intCast(u6, order);
            break;
        }
        faultSum += value;
    }
    return Score.init(activeOrders + 9, .{ .data = faultSum });
}

const Tally = struct {
    map: lib.ManagedStringHashMap(f64),
    countRcp: f64,

    pub fn init(runs: usize, alloc: Allocator) !Self {
        return Self{
            .map = lib.ManagedStringHashMap(f64).init(alloc),
            .countRcp = 1 / @intToFloat(f64, runs),
        };
    }

    pub fn putAndReport(self: *Self, name: []const u8, result: SubTestResult) !f64 {
        if (result.data == std.math.nan_f64) return std.math.inf_f64;

        if (!self.map.contains(name)) try self.map.put(name, 0.0); // TODO: GetOrPut?

        const average = self.map.getPtr(name).?;
        average.* += (1 / @fabs(result.data) - 2.0) * self.countRcp;
        return average.*;
    }

    pub fn conclude(self: *Self) f64 {
        defer self.map.deinit();
        var worstResult: f64 = 0.0;
        var iter = self.map.iterator();
        while (iter.next()) |pair| {
            const value = pair.value_ptr.*;
            if (worstResult < value) worstResult = value;
        }
        return worstResult;
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

// pub fn fault(result: f64) f64 {
//     if (result == std.math.nan_f64) return std.math.inf_f64;
//     const value = @fabs(result); // best = 0.5, worst = 0
//     const biased = 1 / value; //    best = 2.0, worst = inf
//     return biased - 2; //           best = 0.0, worst = inf
// }

// pub fn worst(tests: SubTests, alloc: Allocator) !SubTest { // TODO: delete?
//     var iter = tests.iterator();
//     var result = iter.next() orelse unreachable;
//     while (true) {
//         const pair = iter.next() orelse break;
//         if (@fabs(pair.value_ptr.*) < @fabs(result.value_ptr.*)) result = pair;
//     }
//     return SubTest.init(result.key_ptr.*, result.value_ptr.*, alloc);
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

        pub fn init(seed: RNG.Seed, config: RNG.Config, alloc: Allocator) !Self {
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
            _ = try std.os.fcntl(tester.stdin.?.handle, std.os.F.SETFL, std.os.O.NONBLOCK);
            _ = try std.os.fcntl(tester.stdout.?.handle, std.os.F.SETFL, std.os.O.NONBLOCK);

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
                    w.* = self.rng.next();
                };
                self.writeReady = false;
                self.writer.writeAll(std.mem.sliceAsBytes(self.writeBuffer)) catch {
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
                if (self.readBuffer[self.readIndex] != '\n') continue;
                defer lineStart = self.readIndex + 1;
                const line = self.readBuffer[lineStart..self.readIndex];

                // If line is empty
                if (line.len == 0) if (self.subTests.count() > 0) return false else continue;

                // if un-indented and not table header
                if (std.mem.eql(u8, line[0..2], "  ") and !std.mem.eql(u8, line[2..11], "Test Name")) {
                    // Skip indentation
                    var l: usize = 2;

                    // Find test name
                    while (line[l] != ' ') l += 1;
                    const testName = line[2..l];

                    try self.subTests.put(testName, .{ .data = Self.readResult(line[l..]) });
                }
            }

            // Make space
            std.mem.copy(u8, self.readBuffer[0..], self.readBuffer[lineStart..readLen]);
            self.readIndex -= lineStart;
            return true;
        }

        fn readResult(line: []const u8) f64 {
            var l: usize = 0;

            // Find 'p'
            while (line[l] != 'p') {
                defer l += 1;

                // When instead of 'p' there is "fail" or "pass"
                if (line[l] == '"') return if (line[l + 1] == 'f') 0.0 else 0.5;
            }

            // Jump after '='
            l += 3;

            // Find number start
            while (line[l] == ' ') l += 1;

            // Find number end
            while (line[l] != ' ') l += 1;
            const trailingChar = line[l - 1];

            // If p == "nan"
            if (trailingChar == 'n') return std.math.nan_f64;

            var trailingNumber: f64 = charToF64(trailingChar);
            var trailingDigitCount: f64 = 1;

            // Skip ' ' and last digit
            l -= 2;
            var trailingNumberChar = line[l];

            // Fill trailingNumber
            while (charIsDigit(trailingNumberChar)) {
                const exp = std.math.pow(f64, 10, trailingDigitCount);
                trailingNumber += charToF64(trailingNumberChar) * exp;
                trailingDigitCount += 1;
                l -= 1;
                trailingNumberChar = line[l];
            }

            const nonDigitIndex = l;
            const nonDigitChar = line[nonDigitIndex];

            // If p == '0' or '1'
            if (nonDigitChar == ' ') return if (trailingNumber == 1) -0.0 else 0.0;

            // If p == normal value: "0.188"
            if (nonDigitChar == '.') {
                const value = trailingNumber * std.math.pow(f64, 10, -trailingDigitCount);
                return if (value > 0.5) value - 1.0 else value;
            }

            // p must be in scientific notation
            var coefficient = charToF64(line[nonDigitIndex - 2]);
            var symbolIndex = nonDigitIndex - 3;

            // If coefficient has fraction: "2.3e-4" or "1-2.7e-3"
            if (line[symbolIndex] == '.') {
                coefficient = charToF64(line[nonDigitIndex - 4]) + coefficient / 10;
                symbolIndex -= 2;
            }

            var value = coefficient * std.math.pow(f64, 10, -trailingNumber);
            return if (line[symbolIndex] == '-') -value else value;
        }

        const Self = @This();
    };
}

pub const Score = struct { // TODO: TestScore?
    order: u6 = 0,
    quality: f64 = 0,

    pub fn init(order: u6, fault: SubTestFault) Self {
        return Self{ .order = order, .quality = 33 - std.math.log2(fault.data + 1) };
    }

    pub fn pack(self: Self) f64 {
        return @intToFloat(f64, self.order) * 33 + self.quality;
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const SubTestFault = struct {
    data: f64,

    pub fn init(result: SubTestResult) Self {
        if (result.data == std.math.nan_f64) return Self{ .data = std.math.inf_f64 };
        return Self{ .data = 1 / @fabs(result.data) - 2 };
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

pub const SubTests = lib.ManagedStringHashMap(SubTestResult);

// pub const SubTest = struct {
//     name: []const u8,
//     result: SubTestResult,
//     alloc: Allocator,

//     pub fn init(name: []const u8, result: SubTestResult, alloc: Allocator) !Self {
//         return Self{ .name = try alloc.dupe(u8, name), .result = result, .alloc = alloc };
//     }

//     pub fn deinit(self: *Self) void {
//         self.alloc.free(self.name);
//     }

//     // -------------------------------- Internal --------------------------------

//     const Self = @This();
// };

pub const SubTestResult = struct {
    data: f64,

    pub fn init(raw: f64) Self {
        if (raw == std.math.nan_f64) return Self{ .data = std.math.nan_f64 };
        std.debug.assert(raw > -0.5 and raw <= 0.5);
        return Self{ .data = raw };
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

/// Returns char as f64.
fn charToF64(char: u8) f64 {
    std.debug.assert(charIsDigit(char));
    return @intToFloat(f64, char - '0');
}

/// Returns true if char is '0' trough '9'.
fn charIsDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}
