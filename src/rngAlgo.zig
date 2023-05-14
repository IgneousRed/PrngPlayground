const std = @import("std");
const dev = @import("rng_dev.zig");
const bits = @import("bits.zig");
const Allocator = std.mem.Allocator;

const Port = union { state: u8, inter: u8 };

const Shift = union {
    v: struct {
        p: Port,
        highBits: bool,
        half: bool,
    },
    popCount: Port,
    k: u8,
};

const Operation = union {
    not: Port,
    xor: struct { a: Port, b: Port },
    add: struct { a: Port, b: Port },
    sub: struct { a: Port, b: Port },
    mul: struct { a: Port, v: union { p: Port, k: u8 } },
    shiftLeft: struct { p: Port, a: Shift },
    shiftRight: struct { p: Port, a: Shift },
    rotateLeft: struct { p: Port, a: Shift },
    reverseBytes: Port,
    reverseBits: Port,
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
                .mul => |op| self.port(op.a) *% switch (op.v) {
                    .p => |p| self.port(p) | 1,
                    .k => |k| if (self.config[k] == 0)
                        dev.harmonicMCG(Word)
                    else
                        dev.harmonicLCG(Word),
                },
                .shiftLeft => |op| bits.shlOverflow(self.port(op.p), self.shift(op.a)),
                .shiftRight => |op| bits.shrOverflow(self.port(op.p), self.shift(op.a)),
                .rotateLeft => |op| bits.rolOverflow(self.port(op.p), self.shift(op.a)),
                .reverseBytes => |p| @byteSwap(p),
                .reverseBits => |p| @bitReverse(p),
            };
            for (self.algo.state) |s, i| self.stateNew[i] = self.port(s); // TODO: Counter first?

            const stateBound = self.state.len - 1;
            self.stateNew[stateBound] = self.state[stateBound];
            switch (self.algo.counterType) {
                .basic => self.stateNew[stateBound] +%= dev.oddPhiFraction(Word),
                .mcg => self.stateNew[stateBound] *%= dev.harmonicMCG(Word),
                .lcg => {
                    self.stateNew[stateBound] *%= dev.harmonicLCG(Word);
                    self.stateNew[stateBound] +%= dev.oddPhiFraction(Word);
                },
            }

            std.mem.swap([]Word, &self.state, &self.stateNew); // TODO: ask
            return self.port(self.out);
        }

        // -------------------------------- Internal --------------------------------

        fn port(self: *Self, p: Port) Word {
            return switch (p) {
                .state => |i| self.state[i],
                .inter => |i| self.intermediate[i],
            };
        }

        fn shift(self: *Self, s: Shift) Word {
            return switch (s.a) {
                .v => |v| blk: {
                    var typ = bits.ShiftType(Word);
                    if (v.half) typ = bits.U(@typeInfo(typ).Int.bits - 1);
                    const value = self.port(v.p);
                    break :blk if (v.highBits) bits.high(typ, value) else bits.low(typ, value);
                },
                .popCount => |p| @popCount(self.port(p)),
                .k => |k| self.config[k] + 1,
            };
        }

        const Self = @This();
    };
}
