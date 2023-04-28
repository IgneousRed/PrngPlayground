const std = @import("std");
const mem = std.mem;
const os = std.os;
const math = std.math;
const debug = std.debug;
const dev = @import("rng_dev.zig");
const StringHashMap = std.StringHashMap;
const Allocator = mem.Allocator;
const BoundedArray = std.BoundedArray;
const rand = std.rand;
const Random = rand.Random;

pub fn configRNG(
    comptime RNG: type,
    comptime maxOrder: u6,
    details: bool,
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
                if (i == bestI) continue;

                conf.* = i;
                const result = try testRNG(RNG, maxOrder, runs, config, alloc);

                const report = .{ RNG.configName[c], i, result.order, result.quality };
                if (details) std.debug.print("    {s}: {}, order: {}, quality: {d}\n", report);

                if (best.pack() < result.pack()) {
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

fn TestResults(comptime RNG: type) type {
    return struct {
        data: std.AutoHashMap(RNG.Config, Data),

        pub fn init(alloc: Allocator) Self {
            return .{ .data = std.AutoHashMap(RNG.Config, Data).init(alloc) };
        }

        pub fn load(alloc: Allocator) Self {
            const read = 0;
            _ = mem.bytesToValue(Data, read);
            return Self.init(alloc);
        }

        pub fn save(self: *Self, config: RNG.Config) void {
            // std.fs.Dir.createFile(self: Dir, sub_path: []const u8, flags: File.CreateFlags)
            _ = mem.toBytes(self.data.get(config).?);
        }

        // -------------------------------- Internal --------------------------------

        const Data = struct { orderCount: usize, orderRuns: [][]Fault };
        const Self = @This();
    };
}

const Fault = f64; // TODO: SubTestFault?

const NonBlockingLineReader = struct {
    reader: std.fs.File.Reader,
    buffer: []u8,
    read: usize = 0,
    lineStart: usize = 0,
    end: usize = 0,

    pub fn init(file: std.fs.File, bufferSize: usize, alloc: Allocator) !Self {
        _ = try os.fcntl(file.handle, os.F.SETFL, os.O.NONBLOCK);
        return .{ .reader = file.reader(), .buffer = try alloc.alloc(u8, bufferSize) };
    }

    pub fn line(self: *Self) ?[]const u8 {
        // If buffer has available
        const result = self.parse();
        if (result != null) return result;

        // If space could be freed
        if (self.lineStart > 0) {
            mem.copy(u8, self.buffer[0..], self.buffer[self.lineStart..self.end]);
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
