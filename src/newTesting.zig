const std = @import("std");
const dev = @import("rng_dev.zig");
const Allocator = std.mem.Allocator;

// pub fn configRNG(
//     comptime RNG: type,
//     comptime maxOrder: u6,
//     details: bool,
//     alloc: Allocator,
// ) !void {
//     const timeStart = std.time.timestamp();
//     while (true) {
//         // Config, run
//         const result = try testRNG(RNG, config, maxOrder, run, alloc);
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
            _ = std.mem.bytesToValue(Data, read);
            return Self.init(alloc);
        }

        pub fn save(self: *Self, config: RNG.Config) void {
            // std.fs.Dir.createFile(self: Dir, sub_path: []const u8, flags: File.CreateFlags)
            _ = std.mem.toBytes(self.data.get(config).?);
        }

        // -------------------------------- Internal --------------------------------

        const Data = struct { orderCount: usize, orderRuns: [][]SubTests };
        const Self = @This();
    };
}
fn testRNG(
    comptime RNG: type,
    comptime maxOrder: u6,
    config: RNG.Config,
    run: u64,
    alloc: Allocator,
) SubTests {
    _ = alloc;
    _ = run;
    _ = config;
    if (maxOrder < 10) return .{};

    var activeOrders = maxOrder - 9;
    var orderResults: [activeOrders]SubTests = undefined;
    _ = orderResults;
}

const threshold = 1 << 40; // 1_099_511_627_776 TODO: Test Empiricaly

// pub fn testRngOld(
//     comptime RNG: type,
//     comptime maxOrder: u6,
//     runCount: usize,
//     config: RNG.Config,
//     alloc: Allocator,
// ) !SubTests {
//     if (maxOrder < 10) return .{};

//     var activeOrders = maxOrder - 9;
//     var ordersTally = try alloc.alloc(Tally, activeOrders);
//     for (ordersTally) |*tally| tally.* = try Tally.init(runCount, alloc);
//     var run: usize = 0;
//     runLoop: while (run < runCount) {
//         defer run += 1;
//         var tester = try TestDriver(RNG).init(run, config, alloc);
//         defer tester.deinit();
//         for (ordersTally[0..activeOrders]) |*tally, order| {
//             var subTests = try tester.next();
//             var iter = subTests.iterator();
//             while (iter.next()) |pair| {
//                 const report = try tally.putAndReport(pair.key_ptr.*, pair.value_ptr.*);
//                 if (report >= threshold) {
//                     activeOrders = @intCast(u6, order);
//                     continue :runLoop;
//                 }
//             }
//         }
//     }
//     if (activeOrders == 0) return .{};
//     var faultSum: f64 = 0.0;
//     for (ordersTally[0..activeOrders]) |*tally, order| { // TODO: merge the two for loops
//         const value = tally.conclude();
//         if (faultSum + value >= threshold) {
//             activeOrders = @intCast(u6, order);
//             break;
//         }
//         faultSum += value;
//     }
//     return Score.init(activeOrders + 9, .{ .data = faultSum });
// }

pub const SubTests = std.ManagedStringHashMap(SubTestResult);

const SubTestFault = f64;
const SubTestResult = f64;
