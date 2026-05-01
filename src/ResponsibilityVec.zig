const ResponsibilityVec = @This();

const std = @import("std");

const LinkedMatrix = @import("LinkedMatrix.zig");

values: LinkedMatrix,
arena: std.heap.ArenaAllocator,

pub fn new() ResponsibilityVec {
    return .{
        .values = .init(0),
        .arena = .init(std.heap.page_allocator),
    };
}

pub fn deinit(self: *ResponsibilityVec) void {
    self.arena.deinit();
}

pub fn init(self: *ResponsibilityVec, width: usize, length: usize) bool {
    self.values = .init(width);
    self.values.resize(length, self.arena.allocator()) catch |err| {
        std.debug.print("Failed to initialize ResponsiblityVec {}", .{err});
        return false;
    };
    return true;
}
