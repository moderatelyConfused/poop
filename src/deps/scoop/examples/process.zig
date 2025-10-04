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

pub fn main() !void {
    // Set up debug allocator
    var gpa_state: std.heap.DebugAllocator(.{}) = .init;
    const gpa = gpa_state.allocator();
    defer if (gpa_state.deinit() == .leak) @panic("Memory leaked!");

    // Set up arena allocator
    var arena_state: std.heap.ArenaAllocator = .init(gpa);
    const arena = arena_state.allocator();
    defer arena_state.deinit();

    // Set up counters
    var counters: std.EnumArray(CounterAlias, u64) = .initUndefined();

    // Set up process trace
    const Trace = scoop.Trace(CounterAlias);

    // Sample counters multiple times
    std.debug.print("{s:=^50}\n", .{"PROCESS"});
    for (0..10) |sample_idx| {
        std.debug.print("| Sample Index = {d} |\n", .{sample_idx});

        // Start sampling counters
        var trace: Trace = try .startSampling(arena, &counters, .{ .target_pid = std.c.getpid(), .is_gpa = false });

        // Perform interesting work
        var child: std.process.Child = .init(&.{ "zig", "version" }, gpa);
        child.stdout_behavior = .Ignore;
        _ = try child.spawnAndWait();

        // Stop sampling counters
        try trace.stopSampling();

        // Print counters
        var counter_iter = counters.iterator();
        while (counter_iter.next()) |entry| {
            std.debug.print("{t}: {d}\n", .{ entry.key, entry.value.* });
        }
    }
}
