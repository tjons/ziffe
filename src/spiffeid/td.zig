const std = @import("std");
const uriProtocol = @import("./protocol.zig").uriProtocol;
const testing = std.testing;

// TODO(tjons): implement URI-based equivalents, since Zig has a std.Uri type: https://ziglang.org/documentation/master/std/#std.Uri

/// This type represents a SPIFFE trust domain, as defined in https://github.com/spiffe/spiffe/blob/main/standards/SPIFFE-ID.md#21-trust-domain.
pub const TrustDomain = struct {
    td: []const u8,

    pub fn string(self: TrustDomain) []const u8 {
        return self.td;
    }

    pub fn idString(self: TrustDomain, allocator: std.mem.Allocator) ![]const u8 {
        const result = try allocator.alloc(u8, uriProtocol.len + self.td.len);
        @memcpy(result[0..uriProtocol.len], uriProtocol);
        @memcpy(result[uriProtocol.len..], self.td);

        return result;
    }

    pub fn name(self: TrustDomain) []const u8 {
        return self.string();
    }
};

pub fn TrustDomainFromString(idOrName: []const u8) !TrustDomain {
    var trust_domain = idOrName;
    if (trust_domain.len > uriProtocol.len and std.mem.eql(u8, trust_domain[0..uriProtocol.len], uriProtocol)) {
        trust_domain = trust_domain[uriProtocol.len..];
    }

    try validateTrustDomain(trust_domain);

    return TrustDomain{ .td = trust_domain };
}

const InvalidTrustDomain = error{
    EmptyTrustDomain,
    TrustDomainContainsInvalidCharacters,
    TrustDomainContainsPercentEncodedCharacters,
    TrustDomainContainsUserPart,
    TrustDomainContainsPortPart,
};

// validates a SPIFFE trust domain authority URI segment.
fn validateTrustDomain(idOrName: []const u8) InvalidTrustDomain!void {
    if (idOrName.len == 0) return InvalidTrustDomain.EmptyTrustDomain;
    var other_allowed_character: bool = false;

    for (idOrName) |character| {
        switch (character) {
            '@' => {
                // A SPIFFE trust domain may not contain the `user` part of the URI authority.
                return InvalidTrustDomain.TrustDomainContainsUserPart;
            },
            ':' => {
                // A SPIFFE trust domain may not contain the `port` part of the URI authority.
                return InvalidTrustDomain.TrustDomainContainsPortPart;
            },
            '%' => {
                // A SPIFFE trust domain may not contain any percent-encoded characters.
                return InvalidTrustDomain.TrustDomainContainsPercentEncodedCharacters;
            },
            '_', '-', '.' => {
                // A SPIFFE trust domain may contain `_`, `-`, or `.` characters.
                other_allowed_character = true;
            },
        }

        const digit = std.ascii.isDigit(character);
        const lowercase = std.ascii.isLower(character);

        if (!digit and !lowercase and !other_allowed_character) {
            return InvalidTrustDomain.TrustDomainContainsInvalidCharacters;
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
        try testing.expect(err == InvalidTrustDomain.TrustDomainContainsPortPart);
    };
}

test "It should not allow a SPIFFE trust domain when the trust domain contains a user segment" {
    _ = TrustDomainFromString("user@example.org") catch |err| {
        try testing.expect(err == InvalidTrustDomain.TrustDomainContainsUserPart);
    };
}

test "It should not allow a SPIFFE trust domain when the trust domain contains an uppercase letter" {
    _ = TrustDomainFromString("Atrustdomain.org") catch |err| {
        try testing.expect(err == InvalidTrustDomain.TrustDomainContainsInvalidCharacters);
    };
}

test "It should not allow a SPIFFE trust domain when the trust domain contains invalid characters" {
    _ = TrustDomainFromString("my!trust*domain") catch |err| {
        try testing.expect(err == InvalidTrustDomain.TrustDomainContainsInvalidCharacters);
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
