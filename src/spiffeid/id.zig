pub const std = @import("std");
const uriScheme = @import("protocol.zig").uriScheme;

pub const InvalidSpiffeID = error{
    EmptySpiffeID,
    MissingPrefix,
    MissingTrustDomain,
    MissingPath,
    InvalidCharacters,
};

/// This type represents a SPIFFE ID.
pub const ID = struct {
    trust_domain: []const u8,
    path: []const u8,

    pub fn new(trust_domain: []const u8, path: []const u8) ID {
        return ID{
            .trust_domain = trust_domain,
            .path = path,
        };
    }

    // create a new SpiffeID from a string. Validates the string and parses it
    // into a SpiffeID.
    pub fn from_string(str: []const u8) InvalidSpiffeID!ID {
        if (str.len == 0) return error.EmptySpiffeID;
        if (str.len < uriScheme.len) return error.MissingPrefix;
        if (!std.mem.eql(u8, uriScheme, str[0..9])) return error.MissingPrefix;

        const stripped = str[9..];
        if (stripped.len == 0) return error.MissingTrustDomain;

        const slash_pos = std.mem.indexOfScalar(u8, stripped, '/') orelse 0;
        if (stripped.len - 1 == slash_pos or slash_pos == 0) return error.MissingPath;

        return new(stripped[0..slash_pos], stripped[slash_pos + 1 ..]);
    }

    pub fn string(
        self: ID,
        alc: std.mem.Allocator,
    ) ![]const u8 {
        return std.fmt.allocPrint(alc, "{s}{s}/{s}", .{ uriScheme, self.trust_domain, self.path });
    }

    // The maximum size of a SPIFFE ID is 2048 bytes, which would be nice to represent with an unsigned 11-bit integer.
    // Unfortunately, Zig doesn't seem to like `u11` in the submodule setup.
    pub fn size(self: ID) u64 {
        // include the separating '/' between trust_domain and path and return a
        // usize so this can safely be used for buffer sizing without truncation.
        return uriScheme.len + self.trust_domain.len + 1 + self.path.len;
    }
};

test "Create a SpiffeID and convert back to string" {
    const spiffeID = ID{
        .trust_domain = "example.com",
        .path = "workload/test-workload",
    };

    const allocator = std.heap.page_allocator;
    const str = try spiffeID.string(allocator);

    try std.testing.expect(
        std.mem.eql(u8, str, "spiffe://example.com/workload/test-workload"),
    );
}

test "Parse an empty string as SpiffeID, it should error" {
    _ = ID.from_string("") catch |err| {
        try std.testing.expect(err == InvalidSpiffeID.EmptySpiffeID);
    };
}

test "Parse an incomplete string as SpiffeID, it should error" {
    _ = ID.from_string(uriScheme) catch |err| {
        try std.testing.expect(err == InvalidSpiffeID.MissingTrustDomain);
    };
}

test "Parse a string with protocol and trust domain as SpiffeID, it should error" {
    _ = ID.from_string("spiffe://test-domain") catch |err| {
        try std.testing.expect(err == InvalidSpiffeID.MissingPath);
    };
}

test "Parse a valid string as SpiffeID, it should succeed" {
    const spiffe_id = try ID.from_string("spiffe://test-domain/1");

    try std.testing.expect(
        std.mem.eql(u8, spiffe_id.path, "1"),
    );
    try std.testing.expect(
        std.mem.eql(u8, spiffe_id.trust_domain, "test-domain"),
    );
}
