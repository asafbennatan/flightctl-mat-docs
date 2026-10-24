Status: ready-for-agent

# EDM-4868 — Reject Enrollment Request creation when the issuing CSR is revoked

## Problem Statement

A revoked enrollment credential must not be able to create a new Enrollment Request. Existing certificate deletion does not provide this guarantee because deletion and signing are separate operations, and the current mTLS chain check does not consult the issuing CSR’s revocation state.

## Solution

Reject Enrollment Request creation when the issuing CSR is revoked. The creation path already resolves the enrollment credential to its issuing CSR; fetch that CSR’s authoritative revocation state from the primary database, front the lookup with a Redis cache, and return `403 Forbidden` when the CSR is revoked. If revocation state cannot be determined, fail the request closed.

## User Stories

1. As a security officer, I want a revoked CSR to prevent new Enrollment Request creation, so that a compromised credential cannot onboard another device.
2. As a security officer, I want revocation state fetched from the primary database, so that the decision is authoritative rather than cache-only.
3. As a security officer, I want a Redis cache in front of the database lookup, so that repeated Enrollment Request creation does not add avoidable latency.
4. As a security officer, I want the request to fail closed when revocation state is unavailable, so that an outage cannot silently accept a revoked credential.
5. As a fleet administrator, I want existing devices and management renewal unaffected, so that revocation is admission control rather than eviction.
6. As an API consumer, I want a clear `403 Forbidden` response when the issuing CSR is revoked, so that automation can distinguish authorization failure from a malformed request.

## Implementation Decisions

- Enforce revocation during Enrollment Request creation, not during mTLS connection verification.
- Resolve the issuing CSR from the authenticated enrollment credential by tenant-scoped exact-leaf matching.
- Fetch the CSR’s revocation state from the primary database.
- Cache revocation state in Redis to avoid a database round trip on every Enrollment Request creation.
- Return `403 Forbidden` when the issuing CSR is revoked.
- Fail closed when revocation state cannot be determined.
- Leave existing devices, management-certificate renewal, service-client behavior, and pending Enrollment Requests unchanged.
- Do not introduce CRL, OCSP, a new gateway, or a `VerifyConnection` hook.
- Do not add a certificate-carried CSR-name extension for this check; the resolved CSR row is authoritative.

## Testing Decisions

- Good tests assert externally visible Enrollment Request creation behavior rather than verifier internals.
- Verify that an unrevoked CSR allows Enrollment Request creation.
- Verify that a revoked CSR returns `403 Forbidden`.
- Verify that the database lookup is consulted authoritatively and that Redis only caches its result.
- Verify that a database or cache failure fails closed.
- Verify that existing devices and management renewal remain unchanged.
- Prior art is the existing CSR and Enrollment Request integration tests.

## Out of Scope

- CRL or OCSP infrastructure.
- Device eviction, quarantine, fleet removal, or management/service-client revocation.
- Management-certificate or service-client revocation.
- Changing certificate formats, signer configuration, or the mTLS verification path.
- Rejecting or rewriting existing pending Enrollment Requests.
- Automatically flagging already onboarded Devices.

## Further Notes

- This decision is recorded in ADR 0004, “Reject Enrollment Request creation when the issuing CSR is revoked.”
