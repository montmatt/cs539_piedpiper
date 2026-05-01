const std = @import("std");

const AffectVec = @import("AffectVec.zig");
const ResponsibilityVec = @import("ResponsibilityVec.zig");

var avec: AffectVec = .new();
var rvec: ResponsibilityVec = .new();

export fn init(affectVec: [*:0]const u8, wordVec: [*:0]const u8, numClusters: u32) bool {
    std.debug.print("Recieved string: {s}\n", .{std.mem.span(affectVec)});
    if (!avec.init(std.mem.span(affectVec))) {
        return false;
    }
    if (!rvec.init(numClusters, avec.values.len)) {
        return false;
    }

    std.debug.print("Labels:\n", .{});
    for (avec.labels.items) |label| {
        std.debug.print("{s} ", .{label});
    }
    std.debug.print("\n", .{});

    const row = avec.values.get(0) catch |err| blk: {
        std.debug.print("Failed to get first row. Error: {}\n", .{err});
        const default = [_]f32{};
        break :blk default[0..];
    };
    for (row) |val| {
        std.debug.print("{d} ", .{val});
    }
    std.debug.print("\n", .{});

    const sum = avec.sumAbsValues(avec.arena.allocator()) catch |err| {
        std.debug.print("Failed to sum values. Error: {}\n", .{err});
        return true;
    };
    std.debug.print("The sum is {any}", .{sum});

    _ = wordVec;
    return true;
}

export fn deinit() void {
    avec.deinit();
    rvec.deinit();
}

export fn numDataPoints() usize {
    // return avec.
    return 0;
}

export fn numAffectVecCols() usize {
    return avec.labels.items.len;
}

export fn numAffectVecRows() usize {
    return avec.values.len;
}

export fn numWordVecCols() usize {
    return 0;
}

export fn numWordVecRows() usize {
    return 0;
}

// Returns position of word (row) in WordVec database on given axis
export fn getWordVecvalue(row: usize, axis: usize) f32 {
    _ = row;
    _ = axis;
    return 0.0;
}

// Returns position of word in AffectVec database on given axis
export fn getAffectVecValue(row: usize, axis: usize) f32 {
    if (avec.values.get(row)) |rowVals| {
        return rowVals[axis];
    } else |err| {
        std.debug.print("Failed to read affectVecValue {}", .{err});
        return 0.0;
    }
}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numWordVecRows()
export fn getWordVecPos(row: usize) ?[*]f32 {
    // return avec.get(row).ptr;
    _ = row;
    return null;
}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numAffectVecRows()
export fn getAffectVecPos(word: [*]const u8) ?[*]f32 {
    _ = word;
    return null;
}

// Sum responsibility values for the specified cluster
export fn sumResponsibility(clusterIdx: usize) f32 {
    _ = clusterIdx;
    return 0.0;
}

// Average position of words weighted by responsibility for the given cluster
export fn sumMeanWeightResponsibility(clusterIdx: usize) f32 {
    _ = clusterIdx;
    return 0.0;
}

// Sum responsibilitys
export fn sumResponsibilityWeightedVec(clusterIdx: usize, emotionVec: [*]f32, vecLen: usize) ?[*]f32 {
    _ = clusterIdx;
    _ = emotionVec;
    _ = vecLen;
    return null;
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
