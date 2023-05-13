const std = @import("std");
const dev = @import("rng_dev.zig");
const bits = @import("bits.zig");
const Allocator = std.mem.Allocator;

const Port = union { state: u8, inter: u8 };
const Shift = union { v: struct { p: Port, highBits: bool, half: bool }, popCount: Port, k: u8 };
const Rotate = union { v: struct { p: Port, highBits: bool }, popCount: Port, k: u8 };

const Operation = union {
    not: Port,
    xor: struct { a: Port, b: Port },
    add: struct { a: Port, b: Port },
    sub: struct { a: Port, b: Port },
    mul: struct { a: Port, v: union { p: Port, k: u8 } },
    shiftLeft: struct { p: Port, s: Shift },
    shiftRight: struct { p: Port, s: Shift },
    rotateLeft: struct { p: Port, r: Rotate },
    reverseBits: Port,
    reverseBytes: Port,
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
                    .lcg => |lcg| if (lcg) dev.harmonicLCG(Word) else dev.harmonicMCG(Word),
                },
                .shiftLeft => |op| bits.shlOverflow(self.port(op.p), self.port(op.v)),
                .shiftRight => |op| bits.shrOverflow(self.port(op.p), self.port(op.v)),
                .rotateLeft => |op| bits.rolOverflow(self.port(op.p), self.port(op.v)),
                .reverseBits => |p| @bitReverse(p),
                .reverseBytes => |p| @byteSwap(p),
            };
            for (self.algo.state) |s, i| self.stateNew[i] = self.port(s);

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

        fn shift(self: *Self, s: Shift) Word { // TODO: use
            return switch (s) {
                .v => |v| blk: {
                    comptime var b = std.math.log2(@bitSizeOf(Word));
                    if (v.half) b -= 1;
                    break :blk if (v.highBits)
                        @intCast(bits.ShiftType(Word), @bitSizeOf(Word) - b)
                    else
                        @truncate()
                },
                .popCount => |p| @popCount(self.port(p)),
                .k => |k| k + 1,
            };
        }

        const Self = @This();
    };
}
