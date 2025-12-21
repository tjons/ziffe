const std = @import("std");
const iddef = @import("./id.zig");
const uriScheme = @import("./protocol.zig").uriScheme;
const uriProtocol = @import("./protocol.zig").uriProtocol;
const testing = std.testing;

/// This type represents a SPIFFE trust domain, as defined in https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE-ID.md#21-trust-domain.
/// Several Go SDK methods are intentionally omitted:
/// - text marshalling/unmarshalling
/// - IsZero()
pub const TrustDomain = struct {
    td: []const u8,

    pub fn string(self: TrustDomain) []const u8 {
        return self.td;
    }

    pub fn idString(self: TrustDomain, allocator: std.mem.Allocator) ![]const u8 {
        const result = try allocator.alloc(u8, uriScheme.len + self.td.len);
        @memcpy(result[0..uriScheme.len], uriScheme);
        @memcpy(result[uriScheme.len..], self.td);

        return result;
    }

    pub fn id(self: TrustDomain) iddef.ID {
        return iddef.ID.new(self.td, "");
    }

    pub fn name(self: TrustDomain) []const u8 {
        return self.string();
    }

    // This is somewhat weird and feels like porting a Go idiom to Zig,
    // but I implemented it anyways.
    // TODO(tjons): audit if this is actually the surface we want to expose in time.
    pub fn compare(self: TrustDomain, other: TrustDomain) i8 {
        const ordering = std.mem.order(u8, self.td, other.td);
        switch (ordering) {
            .lt => return -1,
            .gt => return 1,
            .eq => return 0,
        }
    }
};

pub fn TrustDomainFromString(idOrName: []const u8) !TrustDomain {
    var trust_domain = idOrName;
    if (trust_domain.len > uriScheme.len and std.mem.eql(u8, trust_domain[0..uriScheme.len], uriScheme)) {
        trust_domain = trust_domain[uriScheme.len..];
    }

    try validateTrustDomain(trust_domain);

    return TrustDomain{ .td = trust_domain };
}

const InvalidURITrustDomain = error{
    EmptyTrustDomain,
    IncorrectScheme,
    TrustDomainContainsInvalidCharacters,
    TrustDomainContainsPercentEncodedCharacters,
    TrustDomainContainsUserPart,
    TrustDomainContainsPortPart,
};

pub fn TrustDomainFromUri(uri: std.Uri) InvalidURITrustDomain!TrustDomain {
    if (!std.mem.eql(u8, uri.scheme, uriProtocol)) {
        return InvalidURITrustDomain.IncorrectScheme;
    }

    if (uri.port) |_| {
        return InvalidURITrustDomain.TrustDomainContainsPortPart;
    }

    if (uri.user) |_| {
        return InvalidURITrustDomain.TrustDomainContainsUserPart;
    }

    if (uri.password) |_| {
        return InvalidURITrustDomain.TrustDomainContainsUserPart;
    }

    if (uri.host) |host| {
        // Something about this `switch` feels wrong, but
        // I don't know how else to tell the compiler that
        // since these union fields are the same type, I can
        // take either one.
        //
        // As far as I know, `.raw` isn't set at all on the `.host`
        // field during uri parsing, but there's always a chance,
        // so I'll pull both to be extra safe here.
        switch (host) {
            .percent_encoded => |*h| {
                try validateTrustDomain(h.*);
                return TrustDomain{ .td = h.* };
            },
            .raw => |*h| {
                try validateTrustDomain(h.*);
                return TrustDomain{ .td = h.* };
            },
        }
    }

    // If the URI has no host component, return EmptyTrustDomain as it is the most appropriate error in this case.
    return InvalidURITrustDomain.EmptyTrustDomain;
}

pub fn RequireTrustDomainFromUri(uri: std.Uri) TrustDomain {
    return TrustDomainFromUri(uri) catch {
        @panic("Panic: unable to parse trust domain from URI");
    };
}

pub fn RequireTrustDomainFromString(td: []const u8) TrustDomain {
    return TrustDomainFromString(td) catch {
        @panic("Panic: unable to parse trust domain from string");
    };
}

const InvalidStringTrustDomain = error{
    EmptyTrustDomain,
    TrustDomainContainsInvalidCharacters,
    TrustDomainContainsPercentEncodedCharacters,
    TrustDomainContainsUserPart,
    TrustDomainContainsPortPart,
};

// validates a SPIFFE trust domain authority URI segment.
fn validateTrustDomain(idOrName: []const u8) InvalidStringTrustDomain!void {
    if (idOrName.len == 0) return InvalidStringTrustDomain.EmptyTrustDomain;
    var other_allowed_character: bool = false;
    var digit = false;
    var lowercase = false;

    for (idOrName) |character| {
        switch (character) {
            '@' => {
                // A SPIFFE trust domain may not contain the `user` part of the URI authority.
                return InvalidStringTrustDomain.TrustDomainContainsUserPart;
            },
            ':' => {
                // A SPIFFE trust domain may not contain the `port` part of the URI authority.
                return InvalidStringTrustDomain.TrustDomainContainsPortPart;
            },
            '%' => {
                // A SPIFFE trust domain may not contain any percent-encoded characters.
                return InvalidStringTrustDomain.TrustDomainContainsPercentEncodedCharacters;
            },
            '_', '-', '.' => {
                // A SPIFFE trust domain may contain `_`, `-`, or `.` characters.
                other_allowed_character = true;
            },
            else => {
                digit = std.ascii.isDigit(character);
                lowercase = std.ascii.isLower(character);
            },
        }

        if (!digit and !lowercase and !other_allowed_character) {
            return InvalidStringTrustDomain.TrustDomainContainsInvalidCharacters;
        }
    }

    return;
}

test "It should allow a valid SPIFFE trust domain when the trust domain is provided without a protocol segment" {
    const td = try TrustDomainFromString("example.org");
    try testing.expect(std.mem.eql(u8, td.string(), "example.org"));
}

test "It should not allow a SPIFFE trust domain when the trust domain contains a port segment" {
    _ = TrustDomainFromString("example.org:80") catch |err| {
        try testing.expect(err == InvalidStringTrustDomain.TrustDomainContainsPortPart);
    };
}

test "It should not allow a SPIFFE trust domain when the trust domain contains a user segment" {
    _ = TrustDomainFromString("user@example.org") catch |err| {
        try testing.expect(err == InvalidStringTrustDomain.TrustDomainContainsUserPart);
    };
}

test "It should not allow a SPIFFE trust domain when the trust domain contains an uppercase letter" {
    _ = TrustDomainFromString("Atrustdomain.org") catch |err| {
        try testing.expect(err == InvalidStringTrustDomain.TrustDomainContainsInvalidCharacters);
    };
}

test "It should not allow a SPIFFE trust domain when the trust domain contains invalid characters" {
    _ = TrustDomainFromString("my!trust*domain") catch |err| {
        try testing.expect(err == InvalidStringTrustDomain.TrustDomainContainsInvalidCharacters);
    };
}

test "It should allow a SPIFFE trust domain when the trust domain starts with 'spiffe://'" {
    const td = try TrustDomainFromString("spiffe://example.myco.net");
    try testing.expect(std.mem.eql(u8, td.string(), "example.myco.net"));
}

test "It should return the fully qualifed trust domain string" {
    const td = try TrustDomainFromString("spiffe://example.org");
    const id = try td.idString(testing.allocator);
    try testing.expect(std.mem.eql(u8, id, "spiffe://example.org"));
    testing.allocator.free(id);
}

test "It should parse a valid URI as a SPIFFE trust domain" {
    const u = try std.Uri.parse("spiffe://example.org");
    const td = try TrustDomainFromUri(u);
    const id = try td.idString(testing.allocator);
    try testing.expect(std.mem.eql(u8, id, "spiffe://example.org"));
    testing.allocator.free(id);
}

test "It should return the ID type when the TD is populated" {
    const td = try TrustDomainFromString("spiffe://example.org");
    const id = td.id();
    try testing.expect(std.mem.eql(u8, id.trust_domain, "example.org"));
    try testing.expect(std.mem.eql(u8, id.path, ""));
}

test "comparing two trust domains should work as expected" {
    const td1 = RequireTrustDomainFromString("spiffe://example1.org");
    const td2 = RequireTrustDomainFromString("spiffe://example2.org");

    try testing.expect(td1.compare(td2) == -1);
    try testing.expect(td2.compare(td1) == 1);
    try testing.expect(td1.compare(td1) == 0);
}

// It would be really nice if Zig provided a way to manage panics in tests, but from what I can see,
// based on https://github.com/ziglang/zig/issues/1356, this isn't currently possible.
//
// TODO(tjons): cover this behavior in a different suite that is more integration-test like.
test "When calling RequireTrustDomainFromString with an invalid trust domain, it should panic" {}
