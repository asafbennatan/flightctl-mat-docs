Status: ready-for-agent

# EDM-4868 — Project enrollment credentials onto Devices

## Problem Statement

Security officers need to find devices admitted by a revoked enrollment credential without requiring clients to join Enrollment Requests and Devices manually. A separate provenance resource would duplicate the existing same-name relationship and add unnecessary migration and ownership rules.

## Solution

Automatically copy the committed Enrollment Request’s enrollment credential and approving policy into a server-owned Device enrollment-credential status. Revocation materializes both a human-readable condition and a stable selector so affected Devices can be filtered and badged without a client-side join.

## User Stories

1. As a security officer, I want each automatically admitted Device to record its enrollment credential, so that I can trace it after revocation.
2. As a security officer, I want the approving policy recorded on the Device, so that I can understand which rule admitted it.
3. As a security officer, I want affected Devices exposed through indexed selectors, so that I do not need a client-side join.
4. As a fleet administrator, I want a human-readable condition on affected Devices, so that operators can see why a Device is flagged.
5. As a fleet administrator, I want revocation to preserve device lifecycle, labels, and management renewal, so that traceability does not become eviction.
6. As an auditor, I want the projection to be server-owned, so that agents and administrators cannot rewrite credential provenance.
7. As an auditor, I want the projection to reflect committed admission state, so that it cannot authorize new enrollment by itself.
8. As an API consumer, I want Device selectors for credential and policy, so that inventory queries remain consistent.
9. As a Flight Control engineer, I want the existing Enrollment Request-to-Device relationship preserved, so that this change does not add a duplicate foreign key.
10. As a Flight Control engineer, I want status updates protected, so that normal Device reporting cannot erase security provenance.

## Implementation Decisions

- Automatic admission stamps the issuing enrollment-credential name and approving policy onto Device status.
- Revocation materializes a Device condition and a stable revoked selector.
- The projection is denormalized from committed Enrollment Request admission state.
- No Device provenance resource, policy relationship, or duplicate Enrollment Request foreign key is added.
- Agent and administrator status writes cannot replace the projection.
- The projection records audit state and does not authorize new admission.

## Testing Decisions

- Good tests assert externally visible Device status and selectors, not storage internals.
- The primary seam is the existing automatic-admission commit and Device status query path.
- Verify automatic admission stamps credential and policy provenance.
- Verify revocation materializes both the condition and selector.
- Verify normal Device status updates cannot erase the projection.
- Verify indexed credential and policy queries return the expected Devices.
- Prior art is the existing Device status, Enrollment Request, and revocation integration tests.

## Out of Scope

- A new Device provenance resource.
- A new policy relationship resource.
- Rebuilding the existing Enrollment Request-to-Device relationship.
- Using the projection as an authorization decision.

## Further Notes

- This decision is recorded in ADR 0016.
