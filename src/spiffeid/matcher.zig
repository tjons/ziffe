const td = @import("./td.zig");
const id = @import("./id.zig");
const std = @import("std");

pub const MatcherError = error{DoesNotMatch};

pub const Matcher = *const fn (id.ID) MatcherError!void;

// pub const matchAny: Matcher = struct {
//     pub fn call() MatcherError!void {
//         return fn () MatcherError!void{return void};
//     }
// }.call;

const idMatcher = struct {
    expected: id.ID,
    pub fn evaluate(self: idMatcher, check: id.ID) Matcher {
        const trust_domains_match = std.mem.eql(u8, self.expected.trust_domain, check.trust_domain);
        const paths_match = std.mem.eql(u8, self.expected.path, check.path);

        if (!trust_domains_match or !paths_match) {
            return MatcherError.DoesNotMatch;
        }

        return void;
    }
};

pub fn matchID(expected: id.ID) Matcher {
    return struct {
        .m = idMatcher{ .expected = expected },
        pub fn call(self: @This(), check: id.ID) MatcherError!void {
            return self.matcher.evaluate(check);
        }
    }.call;
}

test "matchID should match when the SPIFFE IDs are the same" {
    const expected_id = try id.ID.from_string("spiffe://example.com/workload/1");
    const other_id = try id.ID.from_string("spiffe://example.com/workload/1");
    const matcher = matchID(expected_id);

    try matcher(other_id);
}

test "matchID should error when the SPIFFE IDs are different" {}
