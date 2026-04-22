const std = @import("std");

const AffectVec = @import("AffectVec.zig");

var avec: AffectVec = undefined;

export fn init(affectVec: [*:0]const u8, wordVec: [*:0]const u8, numClusters: u32) bool {
    avec = .new();
    std.debug.print("Recieved string: {s}\n", .{std.mem.span(affectVec)});
    if (!avec.init(std.mem.span(affectVec))) {
        return false;
    }
    std.debug.print("Labels:\n", .{});
    for (avec.labels.items) |label| {
        std.debug.print("{s} ", .{label});
    }
    std.debug.print("\n", .{});

    _ = wordVec;
    _ = numClusters;
    return true;
}

export fn deinit() void {
    avec.deinit();
}

export fn numDataPoints() usize {
    return avec.values.items.len;
}

export fn numAffectVecCols() usize {
    return avec.labels.items.len;
}

export fn numAffectVecRows() usize {
    const cols = avec.labels.items.len;
    if (cols == 0) return 0;

    return avec.values.items.len / cols;
}

export fn numWordVecCols() usize {
    return 0;
}

export fn numWordVecRows() usize {
    return 0;
}

// Returns position of word in WordVec database on given axis
export fn getWordVecPosOnAxis(word: [*]const u8, axis: usize) ?[*]f32 {
    _ = word;
    _ = axis;
    return null;
}

// Returns position of word in AffectVec database on given axis
export fn getAffectVecPosOnAxis(word: [*]const u8, axis: usize) ?[*]f32 {
    _ = word;
    _ = axis;
    return null;
}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numWordVecRows()
export fn getWordVecPos(word: [*]const u8) ?[*]f32 {
    _ = word;
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
export fn sumResponsibilityWeightedMean(clusterIdx: usize) f32 {
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
