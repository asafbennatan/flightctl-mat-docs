Status: ready-for-agent

# EDM-4868 — Enforce enrollment revocation at mTLS without eviction

## Problem Statement

A revoked enrollment credential must stop new device enrollment immediately, including across replicas and resumed TLS sessions, without evicting already enrolled devices or stopping management-certificate renewal. Existing certificate deletion does not provide this guarantee because deletion and signing are separate operations.

## Solution

Enforce enrollment revocation during enrollment mTLS authentication by resolving the exact presented leaf to its issuing CSR and checking the CSR's committed revocation state. A short-lived shared status cache serves repeated checks across replicas, and a committed revocation invalidates its cached status. Revocation rejects associated pending Enrollment Requests, flags automatically onboarded devices within five minutes, and never evicts enrolled devices or interrupts management renewal. Missing or unavailable enforcement state fails closed.

## User Stories

1. As a security officer, I want revocation to block new enrollment immediately, so that a compromised credential cannot onboard more devices.
2. As a security officer, I want enforcement to apply across replicas, so that one server’s revocation is visible everywhere.
3. As a security officer, I want resumed TLS sessions to remain protected, so that an existing connection cannot bypass revocation.
4. As a security officer, I want enforcement to fail closed when authoritative state is unavailable, so that an outage does not silently accept revoked credentials.
5. As a security officer, I want associated pending Enrollment Requests rejected with a reason, so that operators can see why enrollment stopped.
6. As a fleet administrator, I want enrolled devices to remain manageable after credential revocation, so that revocation does not become accidental eviction.
7. As a fleet administrator, I want management-certificate renewal to continue, so that existing devices keep their normal lifecycle.
8. As a fleet administrator, I want affected automatically onboarded devices flagged within five minutes, so that I can investigate them promptly.
9. As an auditor, I want revocation to record actor, time, and reason, so that the security decision is attributable.
10. As an auditor, I want revocation state exposed through the CSR, so that credential inventory remains the source of truth.
11. As a Flight Control engineer, I want revocation to reuse the existing mTLS verification path, so that every enrollment listener is covered without a new gateway.
12. As a Flight Control engineer, I want revocation state to come from the CSR and its shared status cache, so that the control plane has no external revocation-availability dependency.

## Implementation Decisions

- Enrollment authentication resolves the presented leaf through the authenticated tenant's private certificate-digest index and checks the issuing CSR's committed revocation state.
- A short-lived shared status cache serves repeated checks across replicas; a committed revocation invalidates the cached status.
- A cache miss loads authoritative CSR status; revoked, ambiguous, unresolved, and unavailable authoritative state fail closed.
- HTTP enrollment middleware and gRPC stream interception use the same enrollment status check before handlers run, including resumed TLS sessions.
- Revocation commits a durable deny decision, audit record, and pending rejection/flagging work.
- Pending Enrollment Requests bound to the revoked credential are rejected with a distinct reason.
- Automatically onboarded devices associated with the credential are flagged within five minutes.
- Revocation never removes an enrolled Device, stops management renewal, or changes service-client behavior.

## Testing Decisions

- Good tests assert externally visible enrollment, revocation, and Device behavior rather than verifier internals.
- The primary seam is the enrollment mTLS authentication path and revocation API.
- Verify post-commit enrollment requests fail across replicas and resumed sessions.
- Verify cache hits serve repeated checks and committed revocation invalidates the cached status.
- Verify authoritative-store unavailability fails closed.
- Verify pending requests are rejected and affected devices are flagged within the operational bound.
- Verify management renewal and service-client behavior remain unchanged.
- Prior art is the existing TLS verification, CSR, and Enrollment Request integration tests.

## Out of Scope

- CRL or OCSP infrastructure.
- Device eviction, quarantine, or fleet removal.
- Management-certificate or service-client revocation.
- Changing certificate formats or signer configuration.

## Further Notes

- This decision is recorded in ADR 0004.
