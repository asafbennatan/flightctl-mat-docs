---
status: proposed
---

# Project enrollment credentials onto Devices for indexed audit

Automatic admission copies the committed Enrollment Request's enrollment
credential and approving policy into a server-owned Device enrollment
credential status. Revocation materializes both a human-readable
`EnrollmentCredentialRevoked` condition and a stable revoked selector in that
status so affected Devices can be filtered and badged without a client-side
Enrollment Request join.

A separate Device provenance resource, policy relationship, or duplicate ER
foreign key was rejected because the existing same-tenant, same-name
Enrollment Request-to-Device relationship and deletion guard already provide
the live relationship. The projection is deliberately denormalized: agent and
administrator status writes cannot replace it, and it records committed
admission state rather than authorizing new admission or redefining that
relationship.
