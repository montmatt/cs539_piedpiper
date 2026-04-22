const WordVec = @This();

const std = @import("std");

labels: std.ArrayList([]const u8),
values: std.ArrayList([]f32),
arena: std.heap.ArenaAllocator,

fn readLabels(self: *WordVec, reader: *std.Io.Reader) !void {

    // Read size of labels section, then read labels to ref buffer
    const labelsLen = try reader.takeInt(usize, .native);
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

pub fn new() WordVec {
    return .{
        .labels = .empty,
        .values = .empty,
        .arena = .init(std.heap.page_allocator),
    };
}

pub fn init(self: *WordVec, wordVec: []const u8) bool {
    var threaded: std.Io.Threaded = .init_single_threaded;
    const io = threaded.io();

    var file = std.Io.Dir.cwd().openFile(io, wordVec, .{ .mode = .read_only }) catch |err| {
        std.debug.print("Failed to open file. {}\n", .{err});
        return false;
    };
    defer file.close(io);

    var read_buf: [3072]u8 = undefined;
    var fr = file.reader(io, &read_buf);
    const reader = &fr.interface;

    self.readLabels(reader) catch |err| {
        std.debug.print("Failed to read labels. {}\n", .{err});
        return false;
    };

    return true;
}

pub fn deinit(self: *WordVec) void {
    self.arena.deinit();
}
