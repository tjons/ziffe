const std = @import("std");
const spiffeid = @import("id.zig");
const idMatcher = @import("matcher.zig");
var stdin_buffer: [1024]u8 = undefined;
var stdout_buffer: [1024]u8 = undefined;
var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
const stdin = &stdin_reader.interface;
const stdout = &stdout_writer.interface;

pub fn main() !void {
    try stdout.writeAll("Type the spiffe ID\n");
    try stdout.flush();

    const name = try stdin.takeDelimiterExclusive('\n');

    try stdout.print("SPIFFE ID is: {s}\n", .{name});
    try stdout.flush();

    try stdout.writeAll("Type the comparison spiffe ID\n");
    try stdout.flush();

    _ = try stdin.peek(1);
    stdin.toss(1);
    const check_id = try stdin.takeDelimiterExclusive('\n');
    try stdout.print("comp spiffe ID is: {s}\n", .{check_id});
    try stdout.flush();

    const id = try spiffeid.ID.from_string(name);
    const known_id = try spiffeid.ID.from_string(check_id);

    const m = idMatcher.idMatcher{ .expected = &known_id };

    m.evaluate(&id) catch {
        _ = try stdout.write("SPIFFE ID does not match");
        try stdout.flush();
        return;
    };

    _ = try stdout.write("SPIFFE IDs match");
    try stdout.flush();
    return;
}
