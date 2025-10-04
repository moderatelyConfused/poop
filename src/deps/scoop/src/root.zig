//! Root source file that exposes the library's API to users and Autodoc.

const kperf = @import("kperf.zig");

pub const call = kperf.call;
pub const Trace = kperf.Trace;
pub const CounterAlias = kperf.CounterAlias;

pub const xnu = @import("xnu.zig");
