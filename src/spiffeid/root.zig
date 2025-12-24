//! This module provides types and functions for managing SPIFFE IDs.

const id = @import("id.zig");
const td = @import("td.zig");

pub const ID = id.ID;
pub const TrustDomain = td.TrustDomain;

pub const RequireTrustDomainFromString = td.RequireTrustDomainFromString;
pub const RequireTrustDomainFromUri = td.RequireTrustDomainFromUri;
