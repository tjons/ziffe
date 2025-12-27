const td = @import("./td.zig");
const id = @import("./id.zig");
const std = @import("std");

pub const MatcherError = error{DoesNotMatch};
pub const Matcher = fn (*const id.ID) MatcherError!void;

// pub const matchAny: Matcher = struct {
//     pub fn call() MatcherError!void {
//         return fn () MatcherError!void{return void};
//     }
// }.call;

pub const idMatcher = struct {
    expected: *const id.ID,
    pub fn evaluate(self: idMatcher, check: *const id.ID) MatcherError!void {
        const trust_domains_match = std.mem.eql(u8, self.expected.trust_domain, check.trust_domain);
        const paths_match = std.mem.eql(u8, self.expected.path, check.path);

        if (!trust_domains_match or !paths_match) {
            return MatcherError.DoesNotMatch;
        }

        return;
    }
};

pub fn MatchID(expected: *const id.ID) fn (*const id.ID) MatcherError!void {
    const m = idMatcher{ .expected = expected };
    return struct {
        pub fn call(actual: *const id.ID) MatcherError!void {
            return m.evaluate(actual);
        }
    };
}

const mt = fn (actual: id.ID) MatcherError!void;

pub fn MatchStr(expected: *const id.ID) mt {
    const Context = struct {
        expected: *const id.ID,

        pub fn matches(self: @This(), actual: id.ID) MatcherError!void {
            if (std.mem.eql(u8, self.expected.path, actual.path)) {
                return;
            }

            return MatcherError.DoesNotMatch;
        }
    };

    const ctx = Context{ .expected = expected };

    return struct {
        pub fn call(exp: id.ID) MatcherError!void {
            return ctx.matches(exp);
        }
    }.call;
}

// pub fn matchID(expected: id.ID) Matcher {
//     return struct {
//         comptime .m = idMatcher{ .expected = expected },
//         fn call(self: @This(), check: id.ID) MatcherError!void {
//             return self.matcher.evaluate(check);
//         }
//     }.call;
// }

test "matchID should match when the SPIFFE IDs are the same" {
    const expected_id = try id.ID.from_string("spiffe://example.com/workload/1");
    const other_id = try id.ID.from_string("spiffe://example.com/workload/1");
    const matcher = idMatcher{ .expected = expected_id };
    try matcher.evaluate(other_id);
}

test "matchID should error when the SPIFFE IDs are different" {
    const expected_id = try id.ID.from_string("spiffe://example.com/workload/1");
    const other_id = try id.ID.from_string("spiffe://example.com/workload/2");
    const matcher = idMatcher{ .expected = expected_id };

    matcher.evaluate(other_id) catch |err| {
        try std.testing.expect(err == MatcherError.DoesNotMatch);
    };
}

test "does this work" {
    const expected_id = comptime try id.ID.from_string("spiffe://example.com/workload/1");
    const other_id = comptime try id.ID.from_string("spiffe://example.com/workload/2");

    const m = MatchStr(&expected_id);
    m(other_id) catch |err| {
        try std.testing.expect(err == MatcherError.DoesNotMatch);
    };
}
