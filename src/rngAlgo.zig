const std = @import("std");
const dev = @import("rng_dev.zig");
const bits = @import("bits.zig");
const Allocator = std.mem.Allocator;

const Port = union { state: u8, inter: u8 };

const Shift = union {
    value: struct {
        port: Port,
        high: bool,
        half: bool,
    },
    popCount: Port,
    k: u8,
};

const Rotate = union {
    variable: struct { source: union {
        value: struct {
            port: Port,
            high: bool,
            half: bool,
        },
        popCount: Port,
    }, right: bool },
    k: u8,
};

const Operation = union {
    not: Port,
    xor: struct { a: Port, b: Port },
    add: struct { a: Port, b: Port },
    sub: struct { a: Port, b: Port },
    shiftLeft: struct { port: Port, amount: Shift },
    shiftRight: struct { port: Port, amount: Shift },
    rotateRight: struct { port: Port, amount: Shift },
    reverseBytes: Port,
    reverseBits: Port,
    // mul: struct { a: Port, value: union { raw: Port, odd: Port, k: u8 } },
    // append: struct { high: Port, low: Port },
    // low: Port,
    // high: Port,
    // middle: Port,
};

const ConfigType = enum { mul, shift };
const CounterType = enum { basic, mcg, lcg };

const RngAlgo = struct {
    configs: []ConfigType,
    operations: []Operation,
    state: []Port,
    out: Port,
    counterType: CounterType,
    alloc: Allocator,

    pub fn init( // TODO: alloc?
        operations: []Operation,
        state: []Operation,
        out: Port,
        alloc: Allocator,
    ) !Self {
        return .{
            .operations = operations,
            .state = state,
            .out = out,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    // -------------------------------- Internal --------------------------------

    const Self = @This();
};

// const StatesConnected = struct {
//     foundStates: std.DynamicBitSet,
//     foundOperations: std.DynamicBitSet,

//     pub fn asd(algo: *const RngAlgo) !bool {
//         for (algo.state) |st, s| {
//             var self = Self{};
//             const missingStates = try std.DynamicBitSet.initFull(algo.alloc, algo.state.len);
//             defer missingStates.deinit();
//             const missingOperations = try std.DynamicBitSet.initFull(
//                 algo.alloc,
//                 algo.operations.len,
//             );
//             defer missingOperations.deinit();
//             const searchStack = std.ArrayList(Port).initCapacity(
//                 algo.alloc,
//                 algo.state.len + algo.operations.len,
//             );
//             defer searchStack.deinit();
//         }
//     }

//     // -------------------------------- Internal --------------------------------

//     fn addPort(self: *Self, port: Port) void {}

//     const Self = @This();
// };

fn RngState(comptime Word: type) type {
    // const Word2 = bits.U(@bitSizeOf(Word) * 2);
    return struct {
        state: []Word,
        intermediate: []Word,
        stateNew: []Word,

        algo: RngAlgo,
        config: []u8,
        allocator: Allocator,

        pub fn init(algo: RngAlgo, alloc: Allocator) !Self {
            const stateCount = algo.state.len + 1;
            return .{
                .state = try alloc.alloc(Word, stateCount),
                .intermediate = try alloc.alloc(Word, algo.operations.len),
                .stateNew = try alloc.alloc(Word, stateCount),
                .allocator = alloc,
            };
        }

        pub fn next(self: *Self) Word {
            for (self.intermediate) |d, i| d.* = switch (self.operations[i]) {
                .not => |op| ~self.port(op),
                .xor => |op| self.port(op.a) ^ self.port(op.b),
                .add => |op| self.port(op.a) +% self.port(op.b),
                .sub => |op| self.port(op.a) -% self.port(op.b),
                .shiftLeft => |op| bits.shlOvf(self.port(op.p), self.shift(op.a)),
                .shiftRight => |op| bits.shrOvf(self.port(op.p), self.shift(op.a)),
                .rotate => |op| blk: {
                    if (op.amount == .k) break :blk bits.ror(op.port, self.config[op.amount.k]);

                    // const qwe = switch (op.a) {
                    //     .v => |v| asd: {
                    //         var T = bits.ShiftType(Word);
                    //         if (v.half) T = bits.U(@bitSizeOf(T) - 1);
                    //         const value = self.port(v.p);
                    //         break :asd if (v.highBits) bits.high(T, value) else bits.low(T, value);
                    //     },
                    //     .popCount => |p| @popCount(self.port(p)),
                    //     .k => |k| self.config[k] + 1,
                    // };
                    // bits.rolOvf(self.port(op.p), qwe);
                    break :blk 69; // TODO: finish
                },
                .reverseBytes => |p| @byteSwap(p),
                .reverseBits => |p| @bitReverse(p),
                // .mul => |op| @intCast(Word2, self.port(op.a)) * switch (op.v) {
                //     .raw => |p| self.port(p),
                //     .odd => |p| self.port(p) | 1,
                //     .k => |k| switch (self.config[k]) {
                //         0 => dev.harmonicMCG(Word),
                //         1 => dev.harmonicLCG(Word),
                //         else => dev.oddPhiFraction(Word),
                //     },
                // },
                // .append => |op| ,
                // .low => |op| ,
                // .high => |op| ,
                // .middle => |op| ,
            };

            self.stateNew[0] = self.state[0];
            switch (self.algo.counterType) {
                .basic => self.stateNew[0] +%= dev.oddPhiFraction(Word),
                .mcg => self.stateNew[0] *%= dev.harmonicMCG(Word),
                .lcg => {
                    self.stateNew[0] *%= dev.harmonicLCG(Word);
                    self.stateNew[0] +%= dev.oddPhiFraction(Word);
                },
            }

            for (self.algo.state) |s, i| self.stateNew[i + 1] = self.port(s);

            std.mem.swap([*]Word, &self.state.ptr, &self.stateNew.ptr);
            return self.port(self.out);
        }

        // -------------------------------- Internal --------------------------------

        fn shift(self: *Self, s: Shift) Word {
            return switch (s.a) {
                .v => |v| blk: {
                    var T = bits.ShiftType(Word);
                    if (v.half) T = bits.U(@bitSizeOf(T) - 1);
                    const value = self.port(v.p);
                    break :blk if (v.highBits) bits.high(T, value) else bits.low(T, value);
                },
                .popCount => |p| @popCount(self.port(p)),
                .k => |k| self.config[k] + 1,
            };
        }

        fn port(self: *Self, p: Port) Word {
            return switch (p) {
                .state => |i| self.state[i],
                .inter => |i| self.intermediate[i],
            };
        }

        const Self = @This();
    };
}
