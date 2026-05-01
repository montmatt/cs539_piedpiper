const std = @import("std");

const LinkedMatrix = @This();

const Link = struct {
    data: [*]f32, // Explicitly not labeled length
    next: ?*Link,
};

head: ?*Link,
tail: ?*Link,
len: usize,
width: usize,

pub fn init(width: usize) LinkedMatrix {
    return .{
        .head = null,
        .tail = null,
        .len = 0,
        .width = width,
    };
}

// Copys the given row (from) and appends to the end of the list
pub fn appendFrom(self: *LinkedMatrix, alloc: std.mem.Allocator, from: []f32) !void {
    const link = try alloc.create(Link);
    const ownedRow = try alloc.alloc(f32, from.len);
    if (from.len != self.width) unreachable;
    self.len += 1;
    std.mem.copyForwards(f32, ownedRow, from);
    link.* = .{
        .data = ownedRow.ptr,
        .next = null,
    };

    if (self.tail == null) {
        self.head = link;
        self.tail = link;
    } else {
        self.tail.?.next = link;
        self.tail = link;
    }
}

pub fn appendEmpty(self: *LinkedMatrix, alloc: std.mem.Allocator) !void {
    const link = try alloc.create(Link);
    const ownedRow = try alloc.alloc(f32, self.width);
    self.len += 1;
    link.* = .{
        .data = ownedRow.ptr,
        .next = null,
    };

    if (self.tail == null) {
        self.head = link;
        self.tail = link;
    } else {
        self.tail.?.next = link;
        self.tail = link;
    }
}

pub fn resize(self: *LinkedMatrix, targetLen: usize, alloc: std.mem.Allocator) !void {
    if (self.len > targetLen) {
        return error.CannotShrink;
    }
    while (self.len < targetLen) {
        return self.appendEmpty(alloc);
    }
}

const Iter = struct {
    cur: ?*Link,
    width: usize,

    pub fn next(self: *Iter) ?[]f32 {
        if (self.cur == null) return null;
        const res: []f32 = self.cur.?.data[0..self.width]; // self.width
        self.cur = self.cur.?.next;
        return res;
    }
};

pub fn iter(self: *LinkedMatrix) Iter {
    return .{
        .cur = self.head,
        .width = self.width,
    };
}

pub fn get(self: *LinkedMatrix, idx: usize) ![]f32 {
    var curIdx: usize = 0;
    var curIter = self.iter();
    while (curIter.next()) |val| {
        if (curIdx == idx) return val[0..self.width];
        curIdx += 1;
    }
    return error.IndexOutOfRange;
}



let mystr = "hello";
