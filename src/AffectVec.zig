const AffectVec = @This();

const std = @import("std");

const LinkedMatrix = @import("LinkedMatrix.zig");

labels: std.ArrayList([]const u8),
values: LinkedMatrix,
arena: std.heap.ArenaAllocator,

comptime readBufferLen: usize = 3072,

fn readLabels(self: *AffectVec, reader: *std.Io.Reader) !void {

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
    self.labels = .empty;
    while (ownedlabelsBuf.len > 1) {
        var label = ownedlabelsBuf;
        var idx: usize = 0;
        while (ownedlabelsBuf[idx] != 0 and idx < ownedlabelsBuf.len) : (idx += 1) {}
        label.len = idx;
        while (idx < ownedlabelsBuf.len and ownedlabelsBuf[idx] == 0) : (idx += 1) {}
        ownedlabelsBuf = ownedlabelsBuf[idx..];

        try self.labels.append(alloc, label);
    }
}

fn readRow(self: *AffectVec, reader: *std.Io.Reader, width: usize, expectedID: u32) !bool {
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
    try self.values.appendFrom(self.arena.allocator(), rowRef);
    return true;
}

pub fn new() AffectVec {
    return .{
        .labels = .empty,
        .values = .init(0),
        .arena = .init(std.heap.page_allocator),
    };
}

pub fn init(self: *AffectVec, affectVec: []const u8) bool {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var file = std.Io.Dir.cwd().openFile(io, affectVec, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Failed to open file. {}\n", .{err});
        return false;
    };
    defer file.close(io);

    var read_buf: [self.readBufferLen]u8 = undefined;
    var fr = file.reader(io, &read_buf);
    const reader = &fr.interface;

    self.readLabels(reader) catch |err| {
        std.debug.print("Failed to read labels. {}\n", .{err});
        return false;
    };
    self.values = .init(self.labels.items.len);

    var idx: u32 = 1;
    while (true) : (idx += 1) {
        const res = self.readRow(reader, self.labels.items.len, idx) catch |err| {
            std.debug.print("Failed to read row. {}\n", .{err});
            return false;
        };
        if (res == false) break;
    }

    return true;
}

pub fn deinit(self: *AffectVec) void {
    self.arena.deinit();
}

pub fn sumValues(self: *AffectVec, alloc: std.mem.Allocator) ![]f32 {
    const width = self.values.width;
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

pub fn sumAbsValues(self: *AffectVec, alloc: std.mem.Allocator) ![]f32 {
    const width = self.values.width;
    const sum: []f32 = try alloc.alloc(f32, width);
    for (sum) |*val| val.* = 0;

    var iter = self.values.iter();
    while (iter.next()) |vals| {
        for (vals, 0..) |val, idx| {
            sum[idx] += @abs(val);
        }
    }
    return sum;
}
