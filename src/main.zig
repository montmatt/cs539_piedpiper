const std = @import("std");

const GenericVec = @import("UnionedVec.zig");
// const ResponsibilityVec = @import("ResponsibilityVec.zig");

// var rvec: ResponsibilityVec = .new();

var vec: GenericVec = undefined;

export fn init(aVec: [*:0]const u8, wVec: [*:0]const u8, numClusters: u32) bool {
    vec = .new();
    if (!vec.init(std.mem.span(aVec), std.mem.span(wVec), numClusters)) {
        return false;
    }

    std.debug.print("Labels (word vec):\n", .{});
    for (vec.labels_word.items) |label| {
        std.debug.print("{s} ", .{label});
    }

    std.debug.print("Labels (affect vec):\n", .{});
    for (vec.labels_affect.items) |label| {
        std.debug.print("{s} ", .{label});
    }

    std.debug.print("\n", .{});

    const row = vec.values_affect.get(0) catch |err| blk: {
        std.debug.print("Failed to get first row. Error: {}\n", .{err});
        const default = [_]f32{};
        break :blk default[0..];
    };
    for (row) |val| {
        std.debug.print("{d} ", .{val});
    }
    std.debug.print("\n", .{});

    // var gpa = std.testing.allocator;
    // defer _ = gpa.deinit();

    // const sum = vec.sumAbsValuesAffect(_) catch |err| {
    //     std.debug.print("Failed to sum values. Error: {}\n", .{err});
    //     return true;
    // };
    // std.debug.print("The sum of affect vecs is {any}", .{sum});

    return true;
}

export fn deinit() void {
    vec.deinit();
}

// Get data dimensions --------------------------------------------------------

export fn numDataPoints() usize {
    // return vec.
    return vec.values_affect.len;
}

export fn numAffectVecCols() usize {
    return vec.labels_affect.items.len;
}

export fn numWordVecCols() usize {
    return vec.labels_word.items.len;
}

// Get data values ------------------------------------------------------------

// Returns position of word (row) in WordVec database on given axis
export fn getWordVecvalue(row: usize, axis: usize) f32 {
    if (vec.values_word.get(row)) |rowVals| {
        return rowVals[axis];
    } else |err| {
        std.debug.print("Failed to read wordVecValue {}\n", .{err});
        return 0.0;
    }
}

// Returns position of word in AffectVec database on given axis
export fn getAffectVecValue(row: usize, axis: usize) f32 {
    if (vec.values_affect.get(row)) |rowVals| {
        return rowVals[axis];
    } else |err| {
        std.debug.print("Failed to read affectVecValue {}\n", .{err});
        return 0.0;
    }
}

export fn getResponsibilityValue(dataPointIdx: usize, clusterIdx: usize) f32 {
    if (vec.values_resp.get(dataPointIdx)) |rowVals| {
        return rowVals[clusterIdx];
    } else |err| {
        std.debug.print("Failed to read responsibility value. {}\n", .{err});
        return 0.0;
    }
}

// Set data values ------------------------------------------------------------

// Sets value of word (row) in WordVec database on given axis
export fn setWordVecValue(row: usize, axis: usize, value: f32) void {
    if (vec.values_word.get(row)) |rowVals| {
        rowVals[axis] = value;
    } else |err| {
        std.debug.print("Failed to set wordVecValue {}\n", .{err});
    }
}

// Sets value of affect (row) in AffectVec database on given axis
export fn setAffectVecValue(row: usize, axis: usize, value: f32) void {
    if (vec.values_affect.get(row)) |rowVals| {
        rowVals[axis] = value;
    } else |err| {
        std.debug.print("Failed to set affectVecValue {}\n", .{err});
    }
}

// Sets value of responsibility (row) in ResponsibilityVec database on given axis
export fn setResponsibilityValue(dataPointIdx: usize, clusterIdx: usize, value: f32) void {
    if (vec.values_resp.get(dataPointIdx)) |rowVals| {
        rowVals[clusterIdx] = value;
    } else |err| {
        std.debug.print("Failed to set responsibility value {}\n", .{err});
    }
}

// Get data rows ----------------------------------------------------------------

// Returns vector of the given word in the WordVec database
// Length of vector is size of numWordVecRows()
export fn getWordVecPos(row: usize) ?[*]f32 {
    if (vec.values_word.get(row)) |rowVals| {
        return rowVals.ptr;
    } else |err| {
        std.debug.print("Failed to read wordVecPos. {}", .{err});
        return null;
    }
}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numAffectVecRows()
export fn getAffectVecPos(row: usize) ?[*]f32 {
    if (vec.values_affect.get(row)) |rowVals| {
        return rowVals.ptr;
    } else |err| {
        std.debug.print("Failed to read affectVecPos. {}", .{err});
        return null;
    }
}

export fn getResponsibilityVec(row: usize) ?[*]f32 {
    if (vec.values_resp.get(row)) |rowVals| {
        return rowVals.ptr;
    } else |err| {
        std.debug.print("Failed to read responsibility vec. {}", .{err});
        return null;
    }
}

// Sumations over data values -------------------------------------------------------------

// Sum responsibility values for the specified cluster
export fn sumResponsibility(clusterIdx: usize) f32 {
    var sum: f32 = 0;
    var iter = vec.values_resp.iter();
    while (iter.next()) |vals| {
        sum += vals[clusterIdx];
    }
    return sum;
}

// Sumations on data vectors (returns list) -------------------------------------------------------------

// Average position of words weighted by responsibility for the given cluster
export fn sumWordVecWeightResponsibility(clusterIdx: usize, sum: [*]f32, vecLen: usize) bool {
    // Assert vec length matches with of the wordVec database
    if (vecLen != vec.values_word.width) {
        std.debug.print("Length of sum vector does not match with width of wordVec database.\n", .{});
        return false;
    }

    var wIter = vec.values_word.iter();
    var rIter = vec.values_resp.iter();
    while (wIter.next()) |wVals| {
        const rVals = rIter.next().?;
        for (wVals, 0..) |val, idx| {
            sum[idx] += val * rVals[clusterIdx];
        }
    }
    return true;
}

// takes emotion vector. for each datapoint multiplies it by the responsibility of that cluster, and takes the sum of that over all datapoints
export fn sumAffectVecWeightResponsibility(clusterIdx: usize, sumOut: [*]f32, vecLen: usize) bool {
    // Assert vec length matches with of the affectVec database
    std.debug.print("Summing {} {} {}\n", .{ vec.values_affect.width, vecLen, vec.labels_affect.items.len });
    if (vecLen != vec.values_affect.width) {
        std.debug.print("Length of sum vector does not match with width of affectVec database.\n", .{});
        return false;
    }

    var aIter = vec.values_affect.iter();
    var rIter = vec.values_resp.iter();
    while (aIter.next()) |aVals| {
        const rVals = rIter.next().?;
        for (aVals, 0..) |val, idx| {
            sum[idx] += val * rVals[clusterIdx];
        }
    }
    return true;
}

// sum of square distance of data points from given point weighted by the responsibility value
export fn sumWeightedSquareDist(clusterIdx: u32, point: [*]f32) void {
    _ = clusterIdx;
    _ = point;
}

// Updates responsibility value for all points for the specified cluster
export fn updateResponsibility(clusterIdx: usize, emotionVec: [*]f32) void {
    _ = clusterIdx;
    _ = emotionVec;
}
