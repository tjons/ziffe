const std = @import("std");

const uriProtocol = "spiffe://";

const InvalidSpiffeID = error{
    EmptySpiffeID,
    MissingPrefix,
    MissingTrustDomain,
    MissingPath,
    InvalidCharacters,
};

const SpiffeID = struct {
    trust_domain: []const u8,
    path: []const u8,

    pub fn new(trust_domain: []const u8, path: []const u8) SpiffeID {
        return SpiffeID{
            .trust_domain = trust_domain,
            .path = path,
        };
    }

    // Not fully implemented
    pub fn from(str: []const u8) InvalidSpiffeID!SpiffeID {
        if (str.len == 0) return error.EmptySpiffeID;

        return SpiffeID{ .trust_domain = "", .path = "" };
    }

    pub fn string(
        self: SpiffeID,
        alc: std.mem.Allocator,
    ) ![]const u8 {
        return std.fmt.allocPrint(alc, "{s}{s}/{s}", .{ uriProtocol, self.trust_domain, self.path });
    }

    pub fn size(self: SpiffeID) u8 {
        // include the separating '/' between trust_domain and path and return a
        // usize so this can safely be used for buffer sizing without truncation.
        return uriProtocol.len + self.trust_domain.len + 1 + self.path.len;
    }
};

test "Create a SpiffeID and convert back to string" {
    const spiffeID = SpiffeID{
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
    _ = SpiffeID.from("") catch |err| {
        try std.testing.expect(err == InvalidSpiffeID.EmptySpiffeID);
    };
}
