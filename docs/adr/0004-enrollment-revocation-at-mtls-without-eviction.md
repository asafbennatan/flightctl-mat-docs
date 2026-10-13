---
status: proposed
---

# Enforce enrollment revocation at mTLS without eviction

Enrollment-certificate revocation is enforced during mTLS verification
through a `VerifyConnection` hook plus a primary-database barrier on every
enrollment handshake, failing closed when enforcement state is unavailable.
CRL and OCSP were rejected because they add distribution infrastructure and
staleness without improving this single-service control plane.
Deleting the CSR row is not revocation: the service signs certificates and
separately deletes database rows today, so deletion alone cannot revoke a
certificate.

## Non-eviction

Revocation is admission control, not eviction.
It blocks new enrollment immediately, rejects associated pending Enrollment
Requests with a reason, and flags automatically onboarded devices within five
minutes of revocation.
It never removes an enrolled Device, stops management-certificate renewal, or
touches service-client behavior.
Flagging is identification for operators, not quarantine; documentation must
state this distinction explicitly.
