---
status: proposed
---

# Reject Enrollment Request creation when the issuing CSR is revoked

Enrollment-certificate revocation is enforced when an Enrollment Request is
created, not during mTLS connection verification.
The creation path resolves the enrollment credential to its issuing CSR by
tenant-scoped exact-leaf matching. It fetches that CSR's authoritative
revocation state from the primary database, with a Redis cache in front of the
lookup, and returns
`403 Forbidden` when the CSR is revoked.
If revocation state cannot be determined, the request fails closed.
This keeps revocation at the admission-control boundary without adding a
connection hook, CRL/OCSP distribution, or cross-replica handshake coupling.

## Non-eviction

Revocation is admission control, not eviction.
It blocks new Enrollment Request creation for the revoked credential.
It never removes an enrolled Device, stops management-certificate renewal, or
touches service-client behavior.
Existing pending Enrollment Requests continue through their current approval
and rejection flow.
