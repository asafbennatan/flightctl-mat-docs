Status: ready-for-agent

# EDM-4868 — Manually override a Device’s revoked-credential flag

## Problem Statement

A revoked enrollment credential can flag many automatically onboarded Devices, but some flags may be false positives after investigation. Security officers need an auditable way to dismiss an individual Device’s flag without reversing the credential revocation or affecting other Devices.

## Solution

Allow an administrator to dismiss the revoked-credential flag on one Device with an immutable actor, time, and audit reason. The active revoked filter excludes that Device, an audit selector includes it, and the flagging worker treats the override as terminal.

## User Stories

1. As a security officer, I want to dismiss a false-positive flag on one Device, so that operators can focus on real affected devices.
2. As a security officer, I want the override to record actor, time, and reason, so that the decision is auditable.
3. As a security officer, I want the override to affect only one Device, so that dismissing one false positive does not hide others.
4. As a security officer, I want the override to never un-revoke the credential, so that enrollment remains blocked.
5. As a fleet administrator, I want overridden Devices excluded from the active revoked filter, so that operational views stay accurate.
6. As a fleet administrator, I want overridden Devices available in an audit view, so that the history is not lost.
7. As a fleet administrator, I want the flagging worker to respect an override, so that asynchronous work cannot restore a dismissed flag.
8. As an auditor, I want the override to be immutable, so that later edits cannot rewrite the security decision.
9. As an auditor, I want the original revocation and later override both visible, so that I can reconstruct the timeline.
10. As a Flight Control engineer, I want the override to be a narrow per-Device operation, so that it does not become credential-wide un-revocation.

## Implementation Decisions

- An administrator can dismiss the revoked-credential flag on one Device.
- The override records an immutable actor, time, and audit reason.
- The active revoked filter excludes overridden Devices.
- A separate audit selector includes overridden Devices.
- The flagging worker treats a recorded override as terminal.
- The override never un-revokes the credential, re-enables enrollment, restores pending Enrollment Requests, or affects another Device.
- No un-override operation is introduced.

## Testing Decisions

- Good tests assert externally visible Device status, filters, and audit behavior rather than worker internals.
- The primary seam is the existing Device enrollment-credential override API and flagging worker.
- Verify the override records immutable attribution and excludes the Device from the active filter.
- Verify overridden Devices remain available through the audit selector.
- Verify the worker does not rematerialize a dismissed flag.
- Verify revocation and enrollment denial remain in force.
- Prior art is the existing Device status and revocation flagging tests.

## Out of Scope

- Un-revoking an enrollment credential.
- Re-enrolling with a revoked credential.
- Restoring pending Enrollment Request approval.
- Bulk or credential-wide flag overrides.

## Further Notes

- This decision is recorded in ADR 0017.
