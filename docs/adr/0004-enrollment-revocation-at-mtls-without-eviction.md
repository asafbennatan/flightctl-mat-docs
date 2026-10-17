---
status: proposed
---

# Enforce enrollment revocation at mTLS without eviction

Enrollment-certificate revocation is enforced during mTLS verification
through a `VerifyConnection` hook plus a primary-database barrier on every
enrollment handshake, failing closed when enforcement state is unavailable.
The hook obtains the tenant-local CSR name from the authenticated leaf's
[issuer-attested credential binding](0003-enrollment-csr-as-credential-identity.md),
not a fingerprint search to discover identity.
It reads primary state by tenant/name and rejects a missing or revoked
credential, or a leaf inconsistent with the retained issued certificate bytes.
This check runs on resumed sessions too; signed identity is not proof of
current existence or non-revocation.
CRL and OCSP were rejected because they add distribution infrastructure and
staleness without improving this single-service control plane.
Deleting the CSR row is not revocation: the service signs certificates and
separately deletes database rows today, so deletion alone cannot revoke a
certificate.

Enrollment Request creation carries the attested binding from authenticated
context without a separate CSR identity-discovery read.
Authoritative state checks remain part of creation, update, approval, TPM
completion, and final admission, including on established connections.
Mutation checks and their writes must serialize with revocation so a handshake
accepted earlier cannot authorize enrollment after revocation commits.
Neither a successful handshake nor the enrollment identity cache can cache an
unrevoked decision; the enrollment path is not database-free.
Leaves without supported signed identity fail closed without lookup fallback.

## Non-eviction

Revocation is admission control, not eviction.
It blocks new enrollment immediately, rejects associated pending Enrollment
Requests with a reason, and flags automatically onboarded devices within five
minutes of revocation.
It never removes an enrolled Device, stops management-certificate renewal, or
touches service-client behavior.
Flagging is identification for operators, not quarantine; documentation must
state this distinction explicitly.
