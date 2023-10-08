const std = @import("std");
const Allocator = std.mem.Allocator;

const Port = u8;
const Const = u8;
const Shift = union { port: Port, pop: Port, clz: Port, ctz: Port, k: Const };
const Rotate = union { port: Port, pop: Port, clz: Port, ctz: Port };
const Operation = struct {
    port: Port,
    kind: union {
        reverseBytes: void, // ?
        reverseBits: void, // ?
        xor: Port, // !
        add: Port, // !
        sub: Port,
        shiftLeft: Shift,
        shiftRight: Shift,
        shiftArithmetic: Shift,
        rotateLeft: Rotate,
        rotateRight: Rotate,
        rotateConst: Const,
    },
};
const constKind = enum { shift, multiply };
const Algo = struct {
    consts: []constKind,
    operations: []Operation,
    states: []Port,
    out: Port,
};

fn qwe(stateWordCount: u8, operationCount: u8, alloc: Allocator) []Algo {
    _ = operationCount;
    _ = stateWordCount;
    var results = std.ArrayList(Algo).init(alloc);

    return results;
}
