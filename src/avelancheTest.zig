const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn avelancheTest(Rng: type, alloc: Allocator) !void {
    const Word = @TypeOf(Rng.state[0]);
    const wordBits = @bitSizeOf(Word);
    const wordCount = Rng.state.len;
    const bits = wordCount * wordBits;
    const buckets = [2]usize{ try alloc.alloc(usize, bits), try alloc.alloc(usize, bits) };
    var rng = Rng.init(0);
    var i: usize = 0;
    while (i < 1 << 16) : (i += 1) {
        const original = rng.next();
        // For selected freq
        const freq = 0;
        // For all offsets
        const lastState: Rng = undefined; // just the state?
        var b = 0;
        while (b < bits) : (b += 1) {
            var rngCopy = lastState;
            rngCopy.state[b / wordBits] ^= b % wordBits;
            var f = 0;
            while (f < freq) : (f += 1) rngCopy.next();
            const t = qwe(Word, original, rngCopy.next());
            buckets[0] += t.xor;
            buckets[1] += t.add;
        }
    }
}

fn qwe(Word: type, a: Word, b: Word) struct { xor: usize, add: usize } {
    const xor = a ^ b;
    const add = xor ^ std.math.rotl(Word, xor, 1);
    return .{ .xor = @popCount(xor), .add = @popCount(add) };
}

// [freqency][offset][test][bit]
// Signed avelanche?
