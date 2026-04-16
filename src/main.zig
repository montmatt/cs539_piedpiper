export fn add(a: i32, b: i32) i32 {
    return a + b;
}

export fn init(affectvec: [*:0]const u8, wordVec: [*:0]const u8, numClusters: u32) void {}

export fn numDataPoints() usize {}

export fn numAffectVecCols() usize {}

export fn numAffectVecRows() usize {}

export fn numWordVecCols() usize {}

export fn numWordVecRows() usize {}

// Returns position of word in WordVec database on given axis
export fn getWordVecPosOnAxis(word: [*]const u8, axis: usize) [*]f32 {}

// Returns position of word in AffectVec database on given axis
export fn getAffectVecPosOnAxis(word: [*]const u8, axis: usize) [*]f32 {}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numWordVecRows()
export fn getWordVecPos(word: [*]const u8) [*]f32 {}

// Returns vector of the given word in the WordVec database
// Length of vector is size of numAffectVecRows()
export fn getAffectVecPos(word: [*]const u8) [*]f32 {}


// Sum responsibility values for the specified cluster
export fn sumResponsibility(clusterIdx: usize) f32 {}

// Average position of words weighted by responsibility for the given cluster
export fn sumResponsibilityWeightedMean(clusterIdx: usize) {}

// Sum responsibilitys
export fn sumResponsibilityWeightedVec(clusterIdx: usize, emotionVec: [*]f32, vecLen: usize) [*]f32 {}

// sum of square distance of data points from given point weighted by the responsibility value
export fn sumWeightedSquareDist(clusterIdx: u32, point: [*]f32) void {}

// Updates responsibility value for all points for the specified cluster
export fn updateResponsibility(clusterIdx: usize, emotionVec: [*]f32) void {}

