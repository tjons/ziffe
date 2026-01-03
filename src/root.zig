const std = @import("std");
const testing = std.testing;

pub const x509 = @import("bundle/x509bundle/root.zig");
pub const spiffeid = @import("spiffeid");

test "it should be able to use types from submodules" {
    const id = spiffeid.ID{
        .path = "test/path",
        .trust_domain = "example.org",
    };

    const allocator = std.heap.page_allocator;
    const str = try id.string(allocator);

    try std.testing.expect(
        std.mem.eql(u8, str, "spiffe://example.org/test/path"),
    );
}

test {
    testing.refAllDeclsRecursive(@This());
}
