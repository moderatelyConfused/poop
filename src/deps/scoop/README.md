# scoop

## Darwin performance counter observation library that requires root privileges.

### Usage

1. Add `scoop` dependency to `build.zig.zon`:

```sh
zig fetch --save git+https://codeberg.org/tensorush/scoop.git
```

2. Use `scoop` dependency in `build.zig`:

```zig
const scoop_dep = b.dependency("scoop", .{
    .target = target,
    .optimize = optimize,
});
const scoop_mod = scoop_dep.module("scoop");

...
    .imports = &.{
        .{ .name = "scoop", .module = scoop_mod },
    },
...
```
