# Simple Benchmarking for Zig

```zig
const std = @import("std");
const benchmark = @import("benchmark");

const Allocator = std.mem.Allocator;

pub fn main() !void {
  (try benchmark.run(indexOfScalar)).print("indexOScalar");
  (try benchmark.run(indexOfPosLinear)).print("indexOfPosLinear");
}

fn indexOfScalar(_: Allocator, _timer: *std.time.Timer) !void {
  // you can do expensive setup, and then call:
  // timer.reset()
  // to exclude the setup from the measurement

  const input = "it's over 9000!!";
  std.mem.doNotOptimizeAway(std.mem.indexOfScalar(u8, input, '!'));
}

fn indexOfPosLinear(_: Allocator, _timer: *std.time.Timer) !void {
  const input = "it's over 9000!!";
  std.mem.doNotOptimizeAway(std.mem.indexOfPosLinear(u8, input, 0, "!"));
}
```

Will output:

```text
indexOScalar
  16051047 iterations 62.02ns per iterations
  0 bytes per iteration
  worst: 292ns  median: 42ns  stddev: 21.63ns

indexOfPosLinear
  6822614 iterations  145.41ns per iterations
  0 bytes per iteration
  worst: 375ns  median: 125ns stddev: 22.82ns

```

If allocations are made using the provided allocator, the number of bytes requested will be captured and reported. The provided timer can be `reset()` should the benchmark need to do setup work that should not be measured.

The `runC` function will pass an arbitrary context to the benchmark function:

```zig
const Context = struct {
  input: []const u8,
  needle: u8,
};

fn indexOfScalar(_: Allocator, context: Context, _: *std.time.Timer) !void {
  std.mem.doNotOptimizeAway(std.mem.indexOfScalar(u8, context.input, context.needle));
}

pub fn main() !void {
  const context = Context{.input = "it's over 9000!!", .needle = '!'};
  (try benchmark.runC(context, indexOfScalar)).print("indexOScalar");
}
```

## Result
`run` and `runC` return `benchmark.Result`. The `Result` is a little odd: some of the data reflects the total run of the benchmark, and other data is based on samples. This is done in the name of performance.

### Fields
- `total` - total time in nanoseconds that the benchmark took
- `iterations` - total number of benchmark iterations
- `requested_bytes` - total number of requested bytes to the allocator

### print(self: Result, name: []const u8) void
Uses `std.log.debug` to display statistics.

### samples(self: Result) []const u64
Returns ordered timing, in nanosecond, for the sampled values. The samples is currently made up of the last `benchmark.SAMPLE_SIZE` values.

### worst(self: Result) u64
Returns the worst result (i.e. the last value in `result.sample()`).

### mean(self: Result) f64
Returns the mean of the samples.

### median(self: Result) u64
Returns the median of the samples.

### stdDev(self: Result) f64
Returns the standard deviation of the samples
