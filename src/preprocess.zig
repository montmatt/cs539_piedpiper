const std = @import("std");
const Io = std.Io;
const mem = std.mem;

const testing = @import("testing");

fn padded_slice_len(str: []const u8) usize {
    return (str.len) + (4 - str.len % 4);
}

fn header_len(headers: std.ArrayList([]const u8)) usize {
    var len: usize = 0;
    for (headers.items) |header| {
        len += padded_slice_len(header);
    }
    return len;
}

fn write_header(headers: std.ArrayList([]const u8), writer: *std.Io.Writer) !void {
    const total_len: usize = header_len(headers) + @sizeOf(usize);
    try writer.writeInt(usize, total_len, .native);
    // Write each header to the file padded to a multiple of 4 bytes with atleast 1 byte for null terminating
    // std.debug.print("There are {i} headers", .args{headers.len});
    for (headers.items) |header| {
        if (writer.unusedCapacityLen() < padded_slice_len(header))
            try writer.flush(); // Flush buffer if
        try writer.writeAll(header);
        for (0..(4 - header.len % 4)) |_| try writer.writeByte(0);
    }
    try writer.flush();
}

fn process_header(line: []const u8, alloc: std.mem.Allocator) !std.ArrayList([]const u8) {
    var headers = try std.ArrayList([]const u8).initCapacity(alloc, 100);
    var iter = mem.splitAny(u8, line, &std.ascii.whitespace);
    while (iter.next()) |word| {
        if (word.len == 0) continue;
        try headers.append(alloc, word);
    }
    return headers;
}

fn write_row(id: u32, values: std.ArrayList(f32), writer: *std.Io.Writer) !void {
    try writer.writeInt(u32, id, .native);
    for (values.items) |value| {
        if (writer.unusedCapacityLen() < @sizeOf(f32))
            try writer.flush();
        try writer.writeAll(@ptrCast(&value));
    }
    try writer.flush();
}

fn process_row(line: []const u8, expectedValues: usize, word: ?*[]const u8, alloc: std.mem.Allocator) !std.ArrayList(f32) {
    var values = try std.ArrayList(f32).initCapacity(alloc, expectedValues);
    var iter = mem.splitAny(u8, line, &std.ascii.whitespace);
    if (word) |ptr| {
        ptr.* = iter.next() orelse "";
    } else {
        _ = iter.next();
    }

    while (iter.next()) |value_str| {
        if (value_str.len == 0) continue;
        try values.append(alloc, try std.fmt.parseFloat(f32, value_str));
    }
    if (values.items.len != expectedValues) {
        std.debug.print("Invalid number of values in row. Expected {} found {}.", .{ expectedValues, values.items.len });
    }
    return values;
}

fn pre_parse_affectVec(filename: []const u8, dest_file: []const u8, init: std.process.Init, alloc: std.mem.Allocator) !void {
    var srcf = try std.Io.Dir.cwd().openFile(init.io, filename, .{ .mode = .read_only });
    var destf = try std.Io.Dir.cwd().createFile(init.io, dest_file, .{});
    defer srcf.close(init.io);
    defer destf.close(init.io);

    var read_buf: [1024]u8 = undefined;
    var write_buf: [1024]u8 = undefined;

    var fr = srcf.reader(init.io, &read_buf);
    var reader = &fr.interface;

    var fw = destf.writer(init.io, &write_buf);
    const writer = &fw.interface;

    var line = try std.Io.Writer.Allocating.initCapacity(alloc, 2560);
    defer line.deinit();

    const delimiter: u8 = '\n';

    // Read and process header
    var empty: bool = false;
    _ = reader.streamDelimiter(&line.writer, delimiter) catch |err| {
        if (err == error.EndOfStream) empty = true else return err;
    };
    _ = reader.toss(1);

    var headers = try process_header(line.written(), alloc);
    std.debug.print("Headers:", .{});
    for (headers.items) |str| {
        std.debug.print("'{s}'\n", .{str});
    }
    const columns = headers.items.len;
    try write_header(headers, writer);
    headers.deinit(alloc);
    line.clearRetainingCapacity(); // Clear line after free as headers references line buffer

    if (empty) return;

    var i: u32 = 1;
    while (true) : (i += 1) {
        _ = reader.streamDelimiter(&line.writer, delimiter) catch |err| {
            if (err == error.EndOfStream) break else return err;
        };
        _ = reader.toss(1); // Toss delimter

        var row = try process_row(line.written(), columns - 1, null, alloc);
        try write_row(i, row, writer);
        row.deinit(alloc);

        line.clearRetainingCapacity();
    }

    // // Handle any remaining data after the last delimiter.
    // if (line.written().len > 0) {
    //     std.debug.print("{s}\n", .{line.written()});
    // }
}

const affectvec = "datafiles/AffectVec-data.tsv";
const affectvec_dest = "datafiles/compressed_AffectVec";

pub fn main(init: std.process.Init) !void {
    // const allicator = std.heap.ArenaAllocator;
    var arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    try pre_parse_affectVec(affectvec, affectvec_dest, init, alloc);
}
