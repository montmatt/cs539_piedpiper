const std = @import("std");

const GenericVec = @import("UnionedVec.zig");

var vec: GenericVec = undefined;

export fn init(aVec: [*:0]const u8, wVec: [*:0]const u8, numClusters: u32) bool {
    vec = .new();
    if (!vec.init(std.mem.span(aVec), std.mem.span(wVec))) {
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

    const sum = vec.sumAbsValuesAffect(vec.arena.allocator()) catch |err| {
        std.debug.print("Failed to sum values. Error: {}\n", .{err});
        return true;
    };
    std.debug.print("The sum of affect vecs is {any}", .{sum});

    _ = numClusters;
    return true;
}

export fn deinit() void {
    vec.deinit();
}

export fn numDataPoints() usize {
    // return vec.
    return 0;
}

export fn numAffectVecColsAffect() usize {
    return vec.labels_affect.items.len;
}

export fn numAffectVecColsWord() usize {
    return vec.labels_word.items.len;
}

export fn numAffectVecRowsAffect() usize {
    return vec.values_affect.len;
}

export fn numAffectVecRowsWord() usize {
    return vec.values_word.len;
}

export fn numWordVecColsAffect() usize {
    return 0;
}

export fn numWordVecColsWord() usize {
    return 0;
}

export fn numWordVecRowsAffect() usize {
    return 0;
}

export fn numWordVecRowsWord() usize {
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
    return vec.get(row)[axis] catch |err| {
        std.debug.print("Failed to read affectVecValue {}", .{err});
        return null;
    };
}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numWordVecRows()
export fn getWordVecPos(row: usize) ?[*]f32 {
    // return vec.get(row).ptr;
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
