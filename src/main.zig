const std = @import("std");
const lib = @import("lib.zig");
const prng = @import("prng.zig");
const dev = @import("prng_dev.zig");
const bits = @import("bits.zig");
const rand = std.rand;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const alloc = gpa.allocator();

fn mulXsr64(value: u64) u64 {
    var result = value *% 0xcb45348a28cb43bd;
    return result ^ result >> 32;
}

fn mulRor64(value: u64) u64 {
    var result = value *% 0xcb45348a28cb43bd;
    return result ^ lib.ror64(result, 32);
}

fn perm32(value: u32) u32 {
    return @bitReverse(value *% 5);
}

fn mulXsr8(value: u8) u8 {
    var result = value;
    result *%= 0x35;
    result ^= result >> 4;
    result *%= 0x35;
    result ^= result >> 4;
    return result;
}

fn mulRev8(value: u8) u8 {
    var result = value;
    result *%= 0x35;
    result = @bitReverse(result);
    result *%= 0x35;
    result = @bitReverse(result);
    return result;
}

fn perm16(value: u16) u16 {
    // a = ror(a, b);
    // a +%= f(b); (f doesn't need to be reversible)
    // a -%= f(b);
    // a ^= f(b);
    // a *%= k; (k is odd)
    // a +%= a << k;
    // a -%= a << k;
    // a ^= a << k;
    // a ^= a >> k;
    // a = @bitReverse(a);
    var a = value;
    a *%= a;
    return a;
}

pub fn main() !void {
    var child = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin",
    }, alloc);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    try child.spawn();
    const stdIn = child.stdin.?.writer();
    const stdOut = child.stdout.?.reader();

    var state: u64 = 1;
    while (true) {
        state *%= dev.harmonic64MCG64;
        // std.debug.print("Start\n", .{});
        stdIn.writeInt(u32, @intCast(u32, state >> 32), .Little) catch {
            std.debug.print("Crash?\n", .{});
            std.debug.print("{any}\n", .{stdOut.readAllAlloc(alloc, 1024)});
            return;
        };
        // std.debug.print("End\n", .{});
    }

    // try testing();
    // try childTest();
    // drawPerm(mulRev8);
    // try testHash();
    // try testMCG64();
    // permutationCheck(u16, perm16);
    // time();
    // disassembly();
    // mulXshSearch();
}
fn mulXshSearch() void {
    const bitSize = 12;
    const T = bits.U(bitSize);
    var goodCount: usize = 0;
    var mul: T = 5;
    while (true) {
        var add: T = 1;
        while (true) {
            var good = true;
            var set = std.bit_set.ArrayBitSet(usize, 1 << bitSize).initEmpty();
            var state: T = 1;
            var i: usize = 0;
            while (i < 1 << bitSize) {
                var new = state *% mul;
                new +%= add;
                state = new ^ new >> bitSize / 2;
                if (set.isSet(state)) {
                    good = false;
                    break;
                }
                set.set(state);
                i += 1;
            }
            if (good) {
                goodCount += 1;
                // std.debug.print("{d:0>4}\n", .{mul});
                // std.debug.print("{d:0>4} {d:0>4}\n", .{ mul, add });
            }
            add +%= 2;
            if (add == 1) {
                break;
            }
        }
        mul +%= 8;
        if (mul == 5) {
            break;
        }
    }
    const total = (1 << bitSize) * (1 << bitSize);
    const proc = @intToFloat(f64, goodCount) / @intToFloat(f64, total);
    std.debug.print("{} out of {}, or {d}%\n", .{ goodCount, total, proc });
}
fn disassembly() void {
    const count = 1 << 30;
    var state: u64 = 0; // Print the state so compiler does not optimize it away
    const start = std.time.nanoTimestamp();
    for ([1]u0{0} ** count) |_| {
        state *%= 0xd1342543de82ef95;
        state +%= 0xf1357aea2e62a9c5;
        state *%= 0xd1342543de82ef95;
        state +%= 0xf1357aea2e62a9c5;
        state *%= 0xd1342543de82ef95;
        state +%= 0xf1357aea2e62a9c5;
        state *%= 0xd1342543de82ef95;
        state +%= 0xf1357aea2e62a9c5;
    }
    const end = std.time.nanoTimestamp();
    std.debug.print("{d}, {}\n", .{ count / @intToFloat(f64, end - start), state });
}
fn testing() !void {
    var child = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin",
        "-tlmin",
        "10",
        "-tf",
        "2",
        "-te",
        "1",
        "-multithreaded",
    }, alloc);
    child.stdin_behavior = .Pipe;
    // child.stdout_behavior = .Pipe;
    try child.spawn();
    const stdIn = child.stdin.?.writer();

    // const mul64 = 0xd1342543de82ef95; // LCG
    // const mul64 = 0xf1357aea2e62a9c5; // MCG

    // const mul128 = 0xdefba91144f2b375; // M64

    var state: u64 = 1;
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            defer i += 1;
            defer state += 1;

            var a = state;

            // var a = @bitReverse(state);

            // var a = state;
            // a ^= a >> 32;

            // var a = @bitReverse(state);
            // a ^= a >> 32;

            a *%= dev.harmonic64MCG64;
            a ^= a >> 32;
            a *%= dev.harmonic64MCG64;
            a ^= a >> 32;
            a *%= dev.harmonic64MCG64;
            a ^= a >> 32;
            // var result = (a ^ a >> 32) *% dev.harmonic64MCG64;
            // result = (result ^ result >> 32) *% dev.harmonic64MCG64;
            // result = (result ^ result >> 32) *% dev.harmonic64MCG64;
            // result ^= result >> 32;
            // buf[i] = @truncate(u32, result);
            buf[i] = a;
            // buf[i] = @truncate(u32, a);
        }
        try stdIn.writeAll(std.mem.asBytes(&buf));
    }
}
fn childTest() !void {
    var child = std.ChildProcess.init(&[_][]const u8{
        "/Users/gio/PractRand/RNG_test",
        "stdin",
        "-tlmin",
        "10",
        "-tf",
        "2",
        "-te",
        "1",
        "-multithreaded",
    }, alloc);
    child.stdin_behavior = .Pipe;
    child.stdout_behavior = .Pipe;
    try child.spawn();
    const stdIn = child.stdin.?.writer();

    const mul64 = 0xf1357aea2e62a9c5;

    var state: u64 = 0;
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            defer i += 1;
            defer state += 1;
            var a = state;
            // var a = @bitReverse(state);
            a *%= mul64;
            a ^= a >> 32;
            buf[i] = a;
        }
        try stdIn.writeAll(std.mem.asBytes(&buf));
    }
}
fn drawPerm(comptime f: fn (u8) u8) void {
    var lineSpaces = [1]u8{0} ** 256;
    var i: usize = 0;
    while (i < 256) {
        defer i += 1;
        lineSpaces[f(@intCast(u8, i))] = @intCast(u8, i);
    }
    i = 255;
    while (i < 256) {
        defer i -%= 1;
        var j: usize = 0;
        while (j < lineSpaces[i]) {
            defer j += 1;
            std.debug.print(" ", .{});
        }
        std.debug.print("*\n", .{});
    }
}
fn testHash() !void {
    const stdout = std.io.getStdOut().writer();
    var counter: u64 = 0;
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            defer i += 1;
            var result = counter;
            counter += 1;
            var rounds: usize = 0;
            while (rounds < 2) {
                defer rounds += 1;
                // result = mulXsr64(result);
                result = mulRor64(result);
            }
            buf[i] = result;
        }
        try stdout.writeAll(std.mem.asBytes(&buf));
    }
}
fn testMCG64() !void {
    const stdOut = std.io.getStdOut().writer();
    var rng = prng.MCG64.new();
    // var state: u128 = 1;
    var buf = [1]u64{0} ** (1 << 10);
    while (true) {
        var i: usize = 0;
        while (i < buf.len) {
            buf[i] = rng.next64();
            // state *%= 0x2ffd4aa4540b972c007c03e5caca8a0d;
            // buf[i] = lib.ror64(@truncate(u64, state >> 64 - 6), @intCast(u6, state >> 128 - 6));
            i += 1;
        }
        try stdOut.writeAll(std.mem.asBytes(&buf));
    }
}
fn isPermutation(comptime T: type, comptime f: fn (T) T) bool {
    var bitsSet = std.DynamicBitSet.initEmpty(alloc, 1 << @bitSizeOf(T)) catch unreachable;
    var i: T = 0;
    while (true) {
        const index = f(i);
        // std.debug.print("", .{});
        if (bitsSet.isSet(index)) {
            return false;
        }
        bitsSet.set(index);
        i +%= 1;
        if (i == 0) {
            return true;
        }
    }
}
fn permutationCheck(comptime T: type, comptime f: fn (T) T) void {
    const timeStart = std.time.timestamp();
    if (isPermutation(T, f)) {
        std.debug.print("The function is a permutation!\n", .{});
    } else {
        std.debug.print("The function is NOT a permutation\n", .{});
    }
    const delta = std.time.timestamp() - timeStart;
    std.debug.print("Running Time: {} sec\n", .{delta});
}
const S = u64;
// const S = std.rand.DefaultPrng;
const O = u32;
fn in() S {
    return 1;
    // return std.rand.DefaultPrng.init(0);
}
fn stepFn(s: *S) O {
    s.* *%= 0xd1342543de82ef95;
    s.* +%= 0xf1357aea2e62a9c5;
    s.* *%= 0xd1342543de82ef95;
    s.* +%= 0xf1357aea2e62a9c5;
    s.* *%= 0xd1342543de82ef95;
    s.* +%= 0xf1357aea2e62a9c5;
    s.* *%= 0xd1342543de82ef95;
    s.* +%= 0xf1357aea2e62a9c5;
    s.* *%= 0xd1342543de82ef95;
    s.* +%= 0xf1357aea2e62a9c5;
    s.* ^= s.* >> 32;
    return @truncate(u32, s.*);
    // return s.i.random().int(u32);
}
fn time() void {
    timeHelp(O, S, in, stepFn);
}
fn timeHelp(
    comptime Out: type,
    comptime State: type,
    comptime init: fn () State,
    comptime step: fn (*State) Out,
) void {
    var out: Out = undefined;
    var state: State = undefined;
    var best: f64 = 0;
    const endTime = std.time.nanoTimestamp() + 1_000_000_000;
    while (std.time.nanoTimestamp() < endTime) {
        state = init();
        var i: u32 = 0;
        const start = std.time.nanoTimestamp();
        while (i < 1 << 20) {
            defer i += 1;
            out = step(&state);
        }
        const new = @intToFloat(f64, i) / @intToFloat(f64, std.time.nanoTimestamp() - start);
        if (best < new) {
            best = new;
        }
    }
    std.debug.print("{d}, {}\n", .{ best, out });
}

// H1: 15, 0.26701706137000253
// a = (a ^ 61) ^ (a >> 16);
// a = a +% (a << 3);
// a = a ^ (a >> 4);
// a = a *% 0x27d4eb2d;
// a = a ^ (a >> 15);

// H2: 16 0.1867122507122507
// a = (a +% 0x7ed55d16) +% (a << 12);
// a = (a ^ 0xc761c23c) ^ (a >> 19);
// a = (a +% 0x165667b1) +% (a << 5);
// a = (a +% 0xd3a2646c) ^ (a << 9);
// a = (a +% 0xfd7046c5) +% (a << 3);
// a = (a ^ 0xb55a4f09) ^ (a >> 16);

// // H3: 16 0.22750618355391625
// a -%= (a << 6);
// a ^= (a >> 17);
// a -%= (a << 9);
// a ^= (a << 4);
// a -%= (a << 3);
// a ^= (a << 10);
// a ^= (a >> 15);

// // H4: 17 0.22889674743505783
// a +%= ~(a << 15);
// a ^= (a >> 10);
// a +%= (a << 3);
// a ^= (a >> 6);
// a +%= ~(a << 11);
// a ^= (a >> 16);

// // H5: 14 0.21360277042167447
// a = (a +% 0x479ab41d) +% (a << 8);
// a = (a ^ 0xe4aa10ce) ^ (a >> 5);
// a = (a +% 0x9942f0a6) -% (a << 14);
// a = (a ^ 0x5aedd67d) ^ (a >> 3);
// a = (a +% 0x17bea992) +% (a << 7);

// TODO: TEST EVERYTHING!
