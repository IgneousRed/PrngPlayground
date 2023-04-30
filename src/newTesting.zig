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

// pub fn configRNG(
//     comptime RNG: type,
//     comptime maxOrder: u6,
//     details: bool,
//     alloc: Allocator,
// ) !void {
//     var config = RNG.bestKnown;
//     var roundCurrent = round;
//     while (true) {
//         defer roundCurrent += 1;
//         const header = .{ roundCurrent, maxOrder, @typeName(RNG), config };
//         std.debug.print("round: {}, maxOrder: {}, configuring: {s}, bestKnown: {any}\n", header);
//         const timeStart = std.time.timestamp();
//         const runs = @as(usize, 1) << roundCurrent;
//         var best = Score{};
//         for (config) |*conf, c| {
//             var bestI: usize = if (c == 0) -%@as(usize, 1) else conf.*;
//             var i: usize = 0;
//             while (i < RNG.configSize[c]) {
//                 defer i += 1;
//                 if (i == bestI) continue;

//                 conf.* = i;
//                 const result = try testRNG(RNG, maxOrder, runs, config, alloc);

//                 const report = .{ RNG.configName[c], i, result.order, result.quality };
//                 if (details) std.debug.print("    {s}: {}, order: {}, quality: {d}\n", report);

//                 if (best.pack() < result.pack()) {
//                     best = result;
//                     bestI = i;
//                 }
//             }
//             conf.* = bestI;

//             const pick = .{ RNG.configName[c], bestI, best.order, best.quality };
//             if (details) std.debug.print("  {s}: {}, order: {}, quality: {d}\n", pick);
//         }
//         std.debug.print("round: {}, config: {any}, order: {}, quality: {d}, runtime: {}s\n\n", .{
//             roundCurrent,
//             config,
//             best.order,
//             best.quality,
//             std.time.timestamp() - timeStart,
//         });
//         if (!runForever) return;
//     }
// }

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

        const Data = struct { orderCount: usize, orderRuns: [][]SubTests };
        const Self = @This();
    };
}

pub const SubTests = std.ManagedStringHashMap(SubTestResult);

const SubTestFault = f64;
const SubTestResult = f64;
