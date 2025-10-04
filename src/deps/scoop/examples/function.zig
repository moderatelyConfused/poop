const std = @import("std");

const scoop = @import("scoop");

// Any subset of `scoop.CounterAlias`
const CounterAlias = enum {
    Cycles,
    Instructions,
    DataCacheMisses,
    InstructionCacheMisses,
    BranchMisses,
};

fn function(random: std.Random) u32 {
    var last_even: u32 = 0;
    for (0..100_000) |_| {
        const num = random.uintAtMost(u32, std.math.maxInt(u32));
        if (num % 2 == 0) {
            last_even = num;
        }
    }
    return last_even;
}

pub fn main() !void {
    // Set up function arguments
    var prng: std.Random.DefaultPrng = .init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const random = prng.random();

    // Set up counters
    var counters: std.EnumArray(CounterAlias, u64) = .initUndefined();

    // Sample counters multiple times
    std.debug.print("{s:=^30}\n", .{"FUNCTION"});
    for (0..10) |sample_idx| {
        std.debug.print("| Sample Index = {d} |\n", .{sample_idx});

        // Call function and observe changes in counter values
        try scoop.call(CounterAlias, &counters, function, .{random});

        // Print counters
        var counter_iter = counters.iterator();
        while (counter_iter.next()) |entry| {
            std.debug.print("{t}: {d}\n", .{ entry.key, entry.value.* });
        }
    }
}
