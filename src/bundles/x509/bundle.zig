const std = @import("std");
const c = @cImport({
    @cInclude("openssl/x509.h");
    @cInclude("openssl/pem.h");
    @cInclude("openssl/err.h");
});

// Thin Zig wrapper around an OpenSSL X509*
pub const X509Cert = struct {
    // *c.X509 gets null protection with Zig
    ptr: *c.X509,

    pub fn deinit(self: X509Cert) void {
        c.X509_free(self.ptr);
    }
};

// Testing if the C library can load a PEM bundle into managed X509 objects.
// This is hacky, not permenant, just wanted to test the C lib
// Caller owns the returned list with the provided allocator
pub fn loadPemBundle(allocator: std.mem.Allocator, pem_bytes: []const u8) !std.ArrayList(X509Cert) {
    var list = std.ArrayList(X509Cert).init(allocator);

    // Cleanup if we encounter an error
    errdefer {
        for (list.items) |item| item.deinit();
        list.deinit();
        // TODO: bubble up the error?
    }

    // Create an in-memory BIO that OpenSSL can read PEM blocks from.
    // The OpenSSL declaration sees takes a single pointer and expects
    // a NUL-terminated buffer.
    const pem_cstr = try std.mem.concatWithSentinel(allocator, u8, &.{pem_bytes}, 0);
    defer allocator.free(pem_cstr);
    const bio = c.BIO_new_mem_buf(pem_cstr.ptr);
    if (bio == null) return error.OpenSslBioAlloc;
    defer _ = c.BIO_free(bio);

    while (true) {
        // PEM_read_bio_X509 returns null on EOF or error. We disambiguate via ERR_peek_error.
        const cert = c.PEM_read_bio_X509(bio, null, null, null);
        if (cert == null) {
            // If no more data and no errors queued, stop.
            if (c.ERR_peek_error() == 0) break;
            return error.OpenSslPemRead;
        }

        try list.append(.{ .ptr = cert });
    }

    return list;
}

test "loadPemBundle parses empty input" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const result = loadPemBundle(alloc, "") catch |err| {
        // Expect an OpenSSL read failure on empty input.
        try std.testing.expect(err == error.OpenSslPemRead);
        return;
    };
    defer {
        for (result.items) |item| item.deinit();
        result.deinit();
    }
    try std.testing.expect(result.items.len == 0);
}
