---
status: proposed
---

# Project enrollment credential revocation state onto Devices

Automatic admission records the revocation state of the Enrollment Request's
issuing enrollment credential in a server-owned Device status. Revocation
materializes both a human-readable `EnrollmentCredentialRevoked` condition and
a stable revoked selector in that status so affected Devices can be filtered
and badged without a client-side Enrollment Request join.

The issuing credential name stays on the Enrollment Request. Device filters
that select by issuing credential resolve it through the existing same-tenant,
same-name Enrollment Request-to-Device relationship. A separate Device
provenance resource, policy relationship, or duplicate ER foreign key was
rejected because that relationship and its deletion guard already provide the
live link. The projection is deliberately denormalized only for revocation
state: agent and administrator status writes cannot replace it, and it records
committed revocation state rather than authorizing new admission or redefining
that relationship.
