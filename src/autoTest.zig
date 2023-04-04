const std = @import("std");
const mem = std.mem;
const os = std.os;
const math = std.math;
const debug = std.debug;
const dev = @import("prng_dev.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){}; // delete?
const alloc = gpa.allocator();

pub fn allocValue(allocator: mem.Allocator, comptime T: type, value: T, n: usize) ![]T {
    var result = try allocator.alloc(T, n);
    mem.set(T, result, value);
    return result;
}

pub fn testPRNG(comptime prng: type, levels: u6, tries: usize) ![]f64 {
    _ = prng;
    var data: []f64 = try alloc.alloc(f64, levels * tries);
    for (data[0..tries]) |_, t| {
        const start = t * tries;
        mem.copy(f64, data[start .. start + levels], try tryOnce(levels, t));
        std.debug.print("Try{} = {any}\n", .{ t, data[start .. start + levels] });
    }

    const result: []f64 = undefined;
    // std.debug.print("Result = {any}\n", .{result[0..levels]});
    return result; // TODO: Use data
}

fn tryOnce(levels: u6, t: usize) ![]f64 {
    var tester = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin",
        "-p",
        "0.1",
        "-tf",
        "2",
        "-te",
        "1",
        "-tlmin",
        "10",
        "-tlmax",
        "64",
        "-tlmaxonly",
        "-multithreaded",
    }, alloc);
    tester.stdin_behavior = .Pipe;
    tester.stdout_behavior = .Pipe;
    try tester.spawn();
    const testerIn = tester.stdin.?.writer();
    const testerOut = tester.stdout.?.reader();
    _ = try os.fcntl(tester.stdout.?.handle, os.F.SETFL, os.O.NONBLOCK);

    var readIndex: u16 = 0;
    var readLastNL = false;
    var readBuffer = [1]u8{0} ** (1 << 16);
    var writeBuffer = [1]u64{0} ** (1 << 10);
    var state: u64 = t *% dev.oddPhiFraction(u64);

    var introDiscarded = false;
    var level: u6 = 0;
    var result: []f64 = try allocValue(alloc, f64, math.inf_f64, levels);

    // Fill result
    levelLoop: while (true) {
        // Write
        for (writeBuffer) |_, w| {
            var value = state;
            value ^= value >> 32;
            value *%= dev.harmonic64MCG64;
            value ^= value >> 32;
            value *%= dev.harmonic64MCG64;
            value ^= value >> 32;
            value *%= dev.harmonic64MCG64;
            value ^= value >> 32;
            value *%= dev.harmonic64MCG64;
            value ^= value >> 32;
            value *%= dev.harmonic64MCG64;
            value ^= value >> 32;
            writeBuffer[w] = value;
            state += 1;
        }
        try testerIn.writeAll(mem.asBytes(writeBuffer[0..]));

        // Read
        var readCount = testerOut.read(readBuffer[readIndex..]) catch 0;
        if (readCount == 0) continue;
        const readLen = readIndex + @intCast(u16, readCount);

        // Parse readBuffer
        while (true) {
            const charIsNL = readBuffer[readIndex] == '\n';
            readIndex += 1;
            if (!(charIsNL and readLastNL)) {
                readLastNL = charIsNL;
                if (readIndex == readLen) break else continue;
            }
            if (introDiscarded) {
                const value = segmentToFault(readBuffer[0..readIndex]);
                result[level] = value;
                level += 1;
                if (value >= 10_000_000_000 or level == levels) {
                    break :levelLoop;
                }
            } else introDiscarded = true;
            const readLenNew = readLen - readIndex;
            mem.copy(u8, readBuffer[0..readLenNew], readBuffer[readIndex..readLen]);
            readIndex = 0;
            if (readIndex == readLen) break;
        }
    }

    const a: []f64 = undefined;
    return a; // TODO: Use data
}

fn charIsDigit(char: u8) bool {
    return char >= '0' and char <= '9';
}

fn charToDigit(char: u8) f64 {
    debug.assert(charIsDigit(char));
    return @intToFloat(f64, char - '0');
}

// Do not give "RNG_test" intro
pub fn segmentToFault(text: []u8) f64 {
    std.debug.print("{s}\n", .{text});
    var i: usize = 0;
    var linesToSkip: usize = 3;

    // Skip the table prefix
    while (linesToSkip > 0) {
        defer i += 1;
        if (text[i] == '\n') linesToSkip -= 1;
    }

    var result: f64 = 0;
    defer std.debug.print("Result: {}\n", .{result});
    var deb = false;

    // Fill result
    lines: while (text[i] != '\n') {
        const str = text[i + 2 .. i + 4];
        std.debug.print("str = {s}\n", .{str});
        // if (mem.eql(u8, str, "mo")) deb = true;

        if (mem.eql(u8, str, "..") or mem.eql(u8, str, "no")) break;

        // Find 'p'
        while (true) {
            defer i += 1;
            const char = text[i];

            // When instead of 'p' there is "fail" or "pass"
            if (char == '"') {
                // When "fail"
                if (text[i + 1] == 'f') {
                    std.debug.print("FAIL\n", .{});
                    return math.inf_f64;
                }

                // When "pass", put i on next line
                std.debug.print("PASS\n", .{});
                while (text[i] != '\n') i += 1;
                i += 1;
                continue :lines;
            }

            // p found
            if (char == 'p') break;
        }

        // Jump after '='
        i += 3;

        // Find number start
        while (text[i] == ' ') i += 1;

        // Find number end
        while (text[i] != ' ') i += 1;
        const numberEnd = i;

        std.debug.print("Context: {c}\n", .{text[numberEnd - 1]});
        var trailingNumber: f64 = charToDigit(text[numberEnd - 1]);
        var trailingDigitCount: f64 = 1;

        // Skip ' ' and last digit
        var trailingNumberIndex = numberEnd - 2;
        var trailingNumberChar = text[trailingNumberIndex];

        // Fill trailingNumber
        while (charIsDigit(trailingNumberChar)) {
            const v = math.pow(f64, 10, trailingDigitCount);
            trailingNumber += charToDigit(trailingNumberChar) * v;
            trailingDigitCount += 1;
            trailingNumberIndex -= 1;
            trailingNumberChar = text[trailingNumberIndex];
        }

        const nonDigitIndex = trailingNumberIndex;
        const nonDigitChar = text[nonDigitIndex];
        if (deb) std.debug.print("Context: {c}\n", .{nonDigitChar});

        // If p == '0' or '1'
        if (nonDigitChar == ' ') {
            std.debug.print("0 OR 1\n", .{});
            return math.inf_f64;
        }

        // If p == normal value: "0.188"
        if (nonDigitChar == '.') {
            const value = trailingNumber / math.pow(f64, 10, trailingDigitCount);
            const q = 1 / (if (value > 0.5) 1 - value else value);
            std.debug.print("{} => {}\n", .{ value, q });
            result += q;
            while (text[i] != '\n') i += 1;
            i += 1;
            continue;
        }

        // p must be in scientific notation
        var coefficient = charToDigit(text[nonDigitIndex - 2]);

        // If coefficient has fraction: "2.3e-4" or "1-2.7e-3"
        if (text[nonDigitIndex - 3] == '.') {
            coefficient = charToDigit(text[nonDigitIndex - 4]) + coefficient / 10;
        }
        const q = math.pow(f64, 10, trailingNumber) / coefficient;
        std.debug.print("{}e-{}\n", .{ coefficient, trailingNumber });
        result += q;

        while (text[i] != '\n') i += 1;
        i += 1;
    }
    std.debug.print("END\n", .{});
    return result;
}

const TestId = u16;

pub const TestNameMap = struct {
    map: std.StringHashMap(TestId),
    inc: TestId,

    pub fn init(allocator: mem.Allocator) Self {
        return Self{
            .map = std.StringHashMap(TestId).init(allocator),
            .inc = 0,
        };
    }

    pub fn testId(self: *Self, testName: []const u8) !TestId {
        return (try self.map.getOrPutValue(testName, blk: {
            defer self.inc += 1;
            break :blk self.inc;
        })).value_ptr.*;
    }

    // internal

    const Self = @This();
};

const lineResult = struct {
    testId: TestId,
    p: f64,
};

fn spike(value: f64) f64 {
    return 1 - @fabs(value * 2 - 1);
}

// fn

fn lineToResult(map: *TestNameMap, line: []u8) !lineResult {
    // Skip "  "
    var i: usize = 2;

    // Find test name end
    while (line[i] != ' ') i += 1;

    const testId = try map.testId(line[2..i]);

    // Find 'p'
    while (line[i] != 'p') {
        defer i += 1;

        if (line[i] != '"') continue;

        // When instead of 'p' there is "fail"
        if (line[i + 1] == 'f') return lineResult{ .testId = testId, .p = 0 };

        // When instead of 'p' there is "pass"
        return lineResult{ .testId = testId, .p = 0.5 };
    }

    // Jump after '='
    i += 3;

    // Find number start
    while (line[i] == ' ') i += 1;

    // Find number end
    while (line[i] != ' ') i += 1;
    const numberEnd = i;

    var trailingNumber: f64 = charToDigit(line[numberEnd - 1]);
    var trailingDigitCount: f64 = 1;

    // Skip ' ' and last digit
    var trailingNumberIndex = numberEnd - 2;
    var trailingNumberChar = line[trailingNumberIndex];

    // Fill trailingNumber
    while (charIsDigit(trailingNumberChar)) {
        trailingNumber += charToDigit(trailingNumberChar) * math.pow(f64, 10, trailingDigitCount);
        trailingDigitCount += 1;
        trailingNumberIndex -= 1;
        trailingNumberChar = line[trailingNumberIndex];
    }

    const nonDigitIndex = trailingNumberIndex;
    const nonDigitChar = line[nonDigitIndex];

    // If p == '0' or '1'
    if (nonDigitChar == ' ') return lineResult{ .testId = testId, .p = 0 };

    // If p == normal value: "0.188"
    if (nonDigitChar == '.') return lineResult{
        .testId = testId,
        .p = spike(trailingNumber * math.pow(f64, 10, -trailingDigitCount)),
    };

    // p must be in scientific notation
    var coefficient = charToDigit(line[nonDigitIndex - 2]);

    // If coefficient has fraction: "2.3e-4" or "1-2.7e-3"
    if (line[nonDigitIndex - 3] == '.') {
        coefficient = charToDigit(line[nonDigitIndex - 4]) + coefficient / 10;
    }
    return lineResult{
        .testId = testId,
        .p = spike(coefficient * math.pow(f64, 10, -trailingNumber)),
    };
}
