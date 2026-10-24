Status: ready-for-agent

# EDM-4868 Part E — Enrollment revocation at Enrollment Request creation

## Problem Statement

Security officers need to stop a compromised or retired enrollment credential from creating new Enrollment Requests. The current mTLS chain check does not consult the issuing CSR’s revocation state, and deleting the CSR row is not a safe revocation mechanism.

## Solution

Add an enrollment-only revocation subresource to the existing CertificateSigningRequest. When an Enrollment Request is created, resolve the issuing CSR for the authenticated enrollment credential, fetch its authoritative revocation state from the primary database, and return `403 Forbidden` if the CSR is revoked. Put a Redis cache in front of the database lookup. If revocation state cannot be determined, fail the request closed.

## User Stories

1. As a security officer, I want to revoke an enrollment credential, so that it cannot create new Enrollment Requests.
2. As a security officer, I want revocation to take effect on the next Enrollment Request creation attempt, so that there is no continuing acceptance window.
3. As a security officer, I want revocation state fetched from the primary database, so that the decision is authoritative.
4. As a security officer, I want a Redis cache in front of the database lookup, so that repeated Enrollment Request creation does not add avoidable latency.
5. As a security officer, I want revocation to fail closed when authoritative state is unavailable, so that an outage cannot silently accept a revoked credential.
6. As a fleet administrator, I want existing devices and management renewal unaffected, so that revocation is admission control rather than eviction.
7. As an API consumer, I want a clear `403 Forbidden` response when the issuing CSR is revoked, so that automation can distinguish authorization failure from a malformed request.

## Implementation Decisions

- Add an enrollment-only revocation subresource to the existing CSR.
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
- Verify that the database lookup is authoritative and that Redis only caches its result.
- Verify that a database or cache failure fails closed.
- Verify that existing devices and management renewal remain unchanged.
- Prior art is the existing CSR and Enrollment Request integration tests.

## Out of Scope

- The shared CEL runtime and enrollment matching engine (Part A).
- EnrollmentApprovalPolicy persistence and locked policy-set behavior (Part B).
- Event-driven automatic admission and the shared approval transaction (Part C).
- CSR issuance metadata (Part D).
- TPM challenge and verification machinery (Part F).
- CLI, UI, end-user documentation, and the 5000-device scale demonstration (Parts G–H).
- CRL or OCSP infrastructure.
- A new public credential resource, alternate credential identifier, or public authorization interface.
- Un-revocation or revocation of management/service-client certificates.
- Device eviction, quarantine, or stopping management-certificate renewal.
- Rejecting or rewriting existing pending Enrollment Requests.
- Automatically flagging already onboarded Devices.
- Reconstructing historical admission provenance where no issuing-CSR reference was stored.
- Signer-filtered CSR inventory.
- A new general mutation framework or transaction callback exposed to callers.

## Further Notes

- Respects ADR 0003 (reuse the enrollment CSR as the credential identity) and ADR 0004 (reject Enrollment Request creation when the issuing CSR is revoked).
- Enrollment Request creation is the admission-control boundary. Existing management access remains governed by its existing certificate and authentication paths.
