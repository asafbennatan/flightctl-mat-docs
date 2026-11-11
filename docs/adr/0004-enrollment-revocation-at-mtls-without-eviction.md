---
status: proposed
---

# Enforce enrollment revocation at mTLS without eviction

Enrollment-certificate revocation is enforced during enrollment mTLS
authentication by resolving the presented leaf to its issuing enrollment
credential CSR. The CSR's committed revocation state is authoritative; a
short-lived shared negative status cache may short-circuit known denials, but
every allow decision revalidates against the authoritative CSR. Missing or
ambiguous leaf resolution and unavailable enforcement state fail closed.
CRL and OCSP were rejected because they add distribution infrastructure and
staleness without improving this single-service control plane.
Deleting the CSR row is not revocation: the service signs certificates and
separately deletes database rows today, so deletion alone cannot revoke a
certificate.

## Consequence delivery

The revocation commit persists the immutable CSR revocation state and an
`EnrollmentCredentialRevoked` audit event in one transaction. The event is
published to the existing worker/task queue after the commit; the queue's
consumer groups, in-flight tracking, and checkpoint provide the same
at-least-once delivery and crash recovery used by other workloads. No separate
outbox or work-record table is introduced for revocation.

## Non-eviction

Revocation is admission control, not eviction.
It blocks new enrollment immediately, rejects associated pending Enrollment
Requests with a reason, and flags automatically onboarded devices within five
minutes of revocation.
It never removes an enrolled Device, stops management-certificate renewal, or
touches service-client behavior.
Flagging uses the server-owned Device enrollment-credential projection
(ADR 0016) and is identification for operators, not quarantine. Operators can
dismiss an individual flag without reversing revocation (ADR 0017);
documentation must state both distinctions explicitly.
