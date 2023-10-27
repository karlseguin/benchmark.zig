const std = @import("std");

const Timer = std.time.Timer;
const Allocator = std.mem.Allocator;

// calculate statistics from the last N samples
pub var SAMPLE_SIZE = 10_000;

// roughly how long to run the benchmark for
pub var RUN_TIME = 1 * std.time.ns_per_s;

pub const Result = struct {
	total: u64,
	iterations: u64,
	requested_bytes: usize,
	// sorted, use samples()
	_samples: [SAMPLE_SIZE]u64,

	pub fn print(self: Result, name: []const u8) void {
		std.debug.print("{s}\n", .{name});
		std.debug.print("  {d} iterations\t{d:.2}ns per iterations\n", .{self.iterations, self.mean()});
		std.debug.print("  {d:.2} bytes per iteration\n", .{self.requested_bytes / self.iterations});
		std.debug.print("  worst: {d}ns\tmedian: {d:.2}ns\tstddev: {d:.2}ns\n\n", .{self.worst(), self.median(), self.stdDev()});
	}

	pub fn samples(self: Result) []const u64 {
		return self._samples[0..@min(self.iterations, SAMPLE_SIZE)];
	}

	pub fn worst(self: Result) u64 {
		const s = self.samples();
		return s[s.len - 1];
	}

	pub fn mean(self: Result) f64 {
		const s = self.samples();

		var total: u64 = 0;
		for (s) |value| {
			total += value;
		}
		return @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(s.len));
	}

	pub fn median(self: Result) u64 {
		const s = self.samples();
		return s[s.len / 2];
	}

	pub fn stdDev(self: Result) f64 {
		const m = self.mean();
		const s = self.samples();

		var total: f64 = 0.0;
		for (s) |value| {
			total += std.math.pow(f64, @as(f64, @floatFromInt(value)) - m, 2);
		}
		const variance = total / @as(f64, @floatFromInt(s.len - 1));
		return std.math.sqrt(variance);
	}
};

pub fn run(func: TypeOfBenchmark(void)) !Result {
	return runC({}, func);
}

pub fn runC(context: anytype, func: TypeOfBenchmark(@TypeOf(context))) !Result {
	var gpa = std.heap.GeneralPurposeAllocator(.{.enable_memory_limit = true}){};
	const allocator = gpa.allocator();

	var total: u64 = 0;
	var iterations: usize = 0;
	var timer = try Timer.start();
	var samples = std.mem.zeroes([SAMPLE_SIZE]u64);

	while (true) {
		iterations += 1;
		timer.reset();

		if (@TypeOf(context) == void) {
			try func(allocator, &timer);
		} else {
			try func(allocator, context, &timer);
		}
		const elapsed = timer.lap();

		total += elapsed;
		samples[@mod(iterations, SAMPLE_SIZE)] = elapsed;
		if (total > RUN_TIME) break;
	}

	std.sort.heap(u64, samples[0..@min(SAMPLE_SIZE, iterations)], {}, resultLessThan);

	return .{
		.total = total,
		._samples = samples,
		.iterations = iterations,
		.requested_bytes = gpa.total_requested_bytes,
	};
}

fn TypeOfBenchmark(comptime C: type) type {
	return switch (C) {
		void => *const fn(Allocator, *Timer) anyerror!void,
		else => *const fn(Allocator, C, *Timer) anyerror!void,
	};
}

fn resultLessThan(context: void, lhs: u64, rhs: u64) bool {
	_ = context;
	return lhs < rhs;
}
