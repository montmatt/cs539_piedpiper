const UnionVec = @This();

const std = @import("std");

const LinkedMatrix = @import("LinkedMatrix.zig");

labels_affect: std.ArrayList([]const u8),
values_affect: LinkedMatrix,

labels_word: std.ArrayList([]const u8),
values_word: LinkedMatrix,

values_resp: LinkedMatrix,

arena: std.heap.ArenaAllocator,

comptime readBufferLen: usize = 3072,

fn readLabelsAffect(self: *UnionVec, reader: *std.Io.Reader) !void {

    // Read size of labels section, then read labels to ref buffer
    const labelsLen = try reader.takeInt(usize, .native);
    if (labelsLen - @sizeOf(usize) > self.readBufferLen) unreachable;
    const labelsBufRef = try reader.take(labelsLen - @sizeOf(usize));

    // copy labels buffer to owned bufer stored in arena allocator
    var alloc = self.arena.allocator();
    var ownedlabelsBuf = try alloc.alloc(u8, labelsBufRef.len);
    std.mem.copyForwards(u8, ownedlabelsBuf, labelsBufRef);
    // Using arena allocator, expecting deallocation when AffectVec.deinit called

    // Iterate through label buffer and extract all null-terminated strings storing in self.labels
    self.labels_affect = .empty;
    while (ownedlabelsBuf.len > 1) {
        var label = ownedlabelsBuf;
        var idx: usize = 0;
        while (ownedlabelsBuf[idx] != 0 and idx < ownedlabelsBuf.len) : (idx += 1) {}
        label.len = idx;
        while (idx < ownedlabelsBuf.len and ownedlabelsBuf[idx] == 0) : (idx += 1) {}
        ownedlabelsBuf = ownedlabelsBuf[idx..];

        try self.labels_affect.append(alloc, label);
    }
}

fn readLabelsWord(self: *UnionVec, reader: *std.Io.Reader) !void {

    // Read size of labels section, then read labels to ref buffer
    const labelsLen = try reader.takeInt(usize, .native);
    if (labelsLen - @sizeOf(usize) > self.readBufferLen) unreachable;
    const labelsBufRef = try reader.take(labelsLen - @sizeOf(usize));

    // copy labels buffer to owned bufer stored in arena allocator
    var alloc = self.arena.allocator();
    var ownedlabelsBuf = try alloc.alloc(u8, labelsBufRef.len);
    std.mem.copyForwards(u8, ownedlabelsBuf, labelsBufRef);
    // Using arena allocator, expecting deallocation when AffectVec.deinit called

    // Iterate through label buffer and extract all null-terminated strings storing in self.labels
    self.labels_word = .empty;
    while (ownedlabelsBuf.len > 1) {
        var label = ownedlabelsBuf;
        var idx: usize = 0;
        while (ownedlabelsBuf[idx] != 0 and idx < ownedlabelsBuf.len) : (idx += 1) {}
        label.len = idx;
        while (idx < ownedlabelsBuf.len and ownedlabelsBuf[idx] == 0) : (idx += 1) {}
        ownedlabelsBuf = ownedlabelsBuf[idx..];

        try self.labels_affect.append(alloc, label);
    }
}

fn readRowAffect(self: *UnionVec, reader: *std.Io.Reader, width: usize, expectedID: u32) !bool {
    const idCheck = reader.takeInt(u32, .native) catch |err| {
        if (err == error.EndOfStream) return false;
        return err;
    };
    if (idCheck != expectedID) {
        std.debug.print("Unexpected ID found in reading row. Found {} expected {}.\n", .{ idCheck, expectedID });
        return error.IllformatedRow;
    }
    if ((width * @sizeOf(f32)) > self.readBufferLen) unreachable;
    const rowRef: []f32 = @ptrCast(@alignCast(try reader.take(width * @sizeOf(f32))));
    try self.values_affect.appendFrom(self.arena.allocator(), rowRef);
    return true;
}

fn readRowWord(self: *UnionVec, reader: *std.Io.Reader, width: usize, expectedID: u32) !bool {
    const idCheck = reader.takeInt(u32, .native) catch |err| {
        if (err == error.EndOfStream) return false;
        return err;
    };
    if (idCheck != expectedID) {
        std.debug.print("Unexpected ID found in reading row. Found {} expected {}.\n", .{ idCheck, expectedID });
        return error.IllformatedRow;
    }
    if ((width * @sizeOf(f32)) > self.readBufferLen) unreachable;
    const rowRef: []f32 = @ptrCast(@alignCast(try reader.take(width * @sizeOf(f32))));
    try self.values_word.appendFrom(self.arena.allocator(), rowRef);
    return true;
}

pub fn new() UnionVec {
    return .{
        .labels_affect = .empty,
        .labels_word = .empty,
        .values_affect = .init(0),
        .values_word = .init(0),
        .values_resp = .init(0),
        .arena = .init(std.heap.page_allocator),
    };
}

pub fn init(self: *UnionVec, affectVec: []const u8, wordVec: []const u8, num_clusters: usize) bool {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    // Read in Affect Vec

    var a_file = std.Io.Dir.cwd().openFile(io, affectVec, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Failed to open file. {}\n", .{err});
        return false;
    };
    defer a_file.close(io);

    var a_read_buf: [self.readBufferLen]u8 = undefined;
    var a_fr = a_file.reader(io, &a_read_buf);
    const a_reader = &a_fr.interface;

    self.readLabelsAffect(a_reader) catch |err| {
        std.debug.print("Failed to read labels. {}\n", .{err});
        return false;
    };
    self.values_affect = .init(self.labels_affect.items.len);

    var idx: u32 = 1;
    while (true) : (idx += 1) {
        const res = self.readRowAffect(a_reader, self.labels_affect.items.len, idx) catch |err| {
            std.debug.print("Failed to read row. {}\n", .{err});
            return false;
        };
        if (res == false) break;
    }

    // Read in word vec

    var w_file = std.Io.Dir.cwd().openFile(io, wordVec, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Failed to open file. {}\n", .{err});
        // return false;
        self.values_resp = .init(num_clusters);
        self.values_resp.resize(self.values_affect.len, self.arena.allocator()) catch |err_| {
            std.debug.print("Failed to initialize responsibility vec. {}\n", .{err_});
            return false;
        };
        return true;
    };
    defer w_file.close(io);

    var w_read_buf: [self.readBufferLen]u8 = undefined;
    var w_fr = w_file.reader(io, &w_read_buf);
    const w_reader = &w_fr.interface;

    self.readLabelsWord(w_reader) catch |err| {
        std.debug.print("Failed to read labels. {}\n", .{err});
        // return false;
    };
    self.values_word = .init(self.labels_word.items.len);

    idx = 1;
    while (true) : (idx += 1) {
        const res = self.readRowWord(w_reader, self.labels_affect.items.len, idx) catch |err| blk: {
            std.debug.print("Failed to read row. {}\n", .{err});
            // return false;
            // return false;
            break :blk false;
        };
        if (res == false) break;
    }
    std.debug.print("Finished reading in data. Read {} rows of affect vec and {} rows of word vec.\n", .{ self.values_affect.len, self.values_word.len });

    // initialize responsibility vec
    self.values_resp = .init(num_clusters);
    self.values_resp.resize(self.values_affect.len, self.arena.allocator()) catch |err| {
        std.debug.print("Failed to initialize responsibility vec. {}\n", .{err});
        return false;
    };
    return true;
}

pub fn deinit(self: *UnionVec) void {
    self.arena.deinit();
}

pub fn sumValuesAffect(self: *UnionVec, alloc: std.mem.Allocator) ![]f32 {
    const width = self.values_affect.width;
    const sum: []f32 = try alloc.alloc(f32, width);
    for (sum) |*val| val.* = 0;

    var iter = self.values.iter();
    while (iter.next()) |vals| {
        for (vals, 0..) |val, idx| {
            sum[idx] += val;
        }
    }
    return sum;
}

pub fn sumValuesWord(self: *UnionVec, alloc: std.mem.Allocator) ![]f32 {
    const width = self.values_word.width;
    const sum: []f32 = try alloc.alloc(f32, width);
    for (sum) |*val| val.* = 0;

    var iter = self.values.iter();
    while (iter.next()) |vals| {
        for (vals, 0..) |val, idx| {
            sum[idx] += val;
        }
    }
    return sum;
}
pub fn sumAbsValuesAffect(self: *UnionVec, alloc: std.mem.Allocator) ![]f32 {
    const width = self.values_affect.width;
    const sum: []f32 = try alloc.alloc(f32, width);
    for (sum) |*val| val.* = 0;

    var iter = self.values_affect.iter();
    while (iter.next()) |vals| {
        for (vals, 0..) |val, idx| {
            sum[idx] += @abs(val);
        }
    }
    return sum;
}

pub fn sumAbsValuesWord(self: *UnionVec, alloc: std.mem.Allocator) ![]f32 {
    const width = self.values_word.width;
    const sum: []f32 = try alloc.alloc(f32, width);
    for (sum) |*val| val.* = 0;

    var iter = self.values_word.iter();
    while (iter.next()) |vals| {
        for (vals, 0..) |val, idx| {
            sum[idx] += @abs(val);
        }
    }
    return sum;
}
