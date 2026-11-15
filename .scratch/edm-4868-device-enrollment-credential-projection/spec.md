Status: ready-for-agent

# EDM-4868 — Project enrollment credential revocation state onto Devices

## Problem Statement

Security officers need to find devices whose admitting enrollment credential was revoked. The issuing credential name already exists on the Enrollment Request, and Devices share the Enrollment Request name, so a duplicate Device credential field is unnecessary. A separate provenance resource would duplicate the existing relationship and add unnecessary migration and ownership rules.

## Solution

Project the enrollment credential's revocation state onto the Device as a server-owned revoked flag and a human-readable condition. Resolve the issuing credential for Device filters through the existing same-tenant, same-name Enrollment Request-to-Device relationship. Revocation materializes the flag, condition, and a stable revoked selector so affected Devices can be filtered and badged without a client-side join.

## User Stories

1. As a security officer, I want each Device to record whether its admitting enrollment credential was revoked, so that I can identify affected Devices.
2. As a security officer, I want affected Devices exposed through a stable revoked selector, so that I do not need a client-side join.
3. As a fleet administrator, I want a human-readable condition on affected Devices, so that operators can see why a Device is flagged.
4. As a fleet administrator, I want revocation to preserve device lifecycle, labels, and management renewal, so that traceability does not become eviction.
5. As an auditor, I want the revocation projection to be server-owned, so that agents and administrators cannot rewrite it.
6. As an auditor, I want the projection to reflect committed revocation state, so that it cannot authorize new admission by itself.
7. As an API consumer, I want a Device credential filter that resolves the issuing credential from the same-name Enrollment Request, so that credential-based inventory remains available without duplicate Device state.
8. As a Flight Control engineer, I want the existing Enrollment Request-to-Device relationship preserved, so that this change does not add a duplicate foreign key.
9. As a Flight Control engineer, I want status updates protected, so that normal Device reporting cannot erase the revocation state.

## Implementation Decisions

- Revocation materializes a Device `revoked` flag and an `EnrollmentCredentialRevoked` condition.
- The Device status does not copy the issuing credential name or approving policy.
- The Device credential filter resolves `enrollment_requests.status.enrollmentCertificateName` through the same-name Enrollment Request.
- The projection is denormalized only for revocation state.
- No Device provenance resource, policy relationship, or duplicate Enrollment Request foreign key is added.
- Agent and administrator status writes cannot replace the projection.
- The projection records audit state and does not authorize new admission.

## Testing Decisions

- Good tests assert externally visible Device status and selectors, not storage internals.
- The primary seam is the revocation consequence worker and the Device status query path.
- Verify revocation materializes the revoked flag and condition.
- Verify the Device credential filter resolves the same-name Enrollment Request.
- Verify normal Device status updates cannot erase the projection.
- Verify the revoked selector returns the expected Devices.
- Verify already-flagged Devices are skipped.
- Prior art is the existing Device status, Enrollment Request, and revocation integration tests.

## Out of Scope

- A new Device provenance resource.
- A new policy relationship resource.
- Copying the issuing credential name or approving policy onto Device status.
- Rebuilding the existing Enrollment Request-to-Device relationship.
- Using the projection as an authorization decision.

## Further Notes

- This decision is recorded in ADR 0016.
