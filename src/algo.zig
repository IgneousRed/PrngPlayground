const std = @import("std");
const Allocator = std.mem.Allocator;

const Port = u8;
const Const = u8;
const Shift = union { port: Port, k: Const };
const Operation = struct {
    port: Port,
    kind: union {
        xor: Port, // !
        add: Port, // !
        sub: Port,
        shiftLeft: Shift,
        shiftRight: Shift,
        rotateLeft: Port,
        rotateRight: Port,
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
