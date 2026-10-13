Status: ready-for-agent

# EDM-4868 Part D — CSR issuance metadata

## Problem Statement

Enrollment approval policies need a durable, server-owned time at which an enrollment certificate was issued, but Flight Control currently publishes only the signed certificate bytes on the issuing CertificateSigningRequest. The existing signing and approval route already works and must not be replaced, but its status publication is not sufficient for an issuance-based auto-approval window because approval time, certificate validity start, and issuance publication are different concepts. The gap also makes historical credentials ambiguous: a CSR that already has certificate bytes but no issuance metadata must be distinguishable from a CSR issued after the new behavior is available.

## Solution

Extend the existing CertificateSigningRequest status contract with an optional, read-only `issuedAt` timestamp. When the existing signing path successfully signs an enrollment-signer CSR, it publishes the certificate bytes and `issuedAt` together in one existing server-owned status update. The timestamp is taken from the server clock at issuance publication, is immutable once committed, and is not backfilled for certificates issued before this change. No new approval route, event type, signer flow, public credential resource, or client-visible mutation path is introduced.

## User Stories

1. As a fleet administrator, I want an enrollment-signer CSR to record exactly when its certificate was issued, so that policy approval windows have a durable starting point.
2. As a fleet administrator, I want issuance time to be server-owned, so that a device cannot influence when its commissioning window starts.
3. As a fleet administrator, I want issuance time recorded only after the certificate is successfully published, so that a signing failure does not start an approval window.
4. As a fleet administrator, I want issuance time to remain stable across retries and status reads, so that repeated worker or client actions cannot restart a policy window.
5. As a fleet administrator, I want existing certificate issuance behavior to remain unchanged, so that this metadata addition does not introduce operational risk.
6. As a fleet administrator, I want historical CSRs to remain valid, so that deploying this change does not invalidate credentials issued earlier.
7. As a fleet administrator, I want historical CSRs without issuance metadata to be visibly incomplete rather than approximated, so that policy evaluation fails closed instead of using a fabricated time.
8. As a security officer, I want certificate bytes and issuance time published atomically, so that a CSR can never expose one half of issuance evidence without the other.
9. As a security officer, I want `issuedAt` to be immutable, so that changing policy history or CSR status cannot move an approval window.
10. As a security officer, I want client-supplied `issuedAt` values to be rejected or ignored, so that only the control plane can create issuance evidence.
11. As a security officer, I want concurrent signing attempts to preserve the first committed issuance result, so that duplicate work cannot produce two issuance truths.
12. As a security officer, I want signing failures to leave both certificate bytes and issuance time unset, so that no partial issuance evidence is persisted.
13. As a security officer, I want the existing issued certificate bytes to remain on the CSR, so that later identity and revocation work can derive the exact leaf certificate.
14. As an auditor, I want issuance metadata to remain attached to the existing CSR identity, so that policies, Enrollment Requests, and certificate evidence can be correlated without a second resource identifier.
15. As an auditor, I want the absence of issuance metadata to be explicit, so that I can distinguish a legacy credential from a newly issued credential.
16. As an API consumer, I want to read `issuedAt` from the normal CSR representation, so that I do not need a separate lookup or API.
17. As an API consumer, I want generated clients to include the new field, so that serialization remains type-safe.
18. As an OT operator, I want issuance time to use the API's standard timestamp format, so that tooling can compare and display it consistently.
19. As an OT operator, I want manual and automatic approval to use the same issuance path, so that certificate metadata does not depend on who approved the request.
20. As an OT operator, I want retries after a failed status publication to produce a complete issuance record, so that transient storage failures do not leave a CSR unissuable.
21. As a Flight Control engineer, I want the existing CSR signing service to own this change, so that issuance evidence is written where issuance actually happens.
22. As a Flight Control engineer, I want to reuse the existing typed CSR status update, so that this part does not introduce a second mutation framework.
23. As a Flight Control engineer, I want deterministic time injection in tests, so that issuance boundaries can be tested without sleeping or rewriting clocks globally.
24. As a Flight Control engineer, I want existing CSR validation and approval behavior preserved, so that this narrowly scoped metadata change does not alter public semantics.
25. As a Flight Control engineer, I want no signer inventory selector in this part, so that issuance metadata is not coupled to an unrelated query capability.

## Implementation Decisions

- Add optional `status.issuedAt` to the CertificateSigningRequest API contract and update hand-maintained types and generated clients.
- Treat `issuedAt` as server-owned and immutable once populated.
- Populate the field only for CSRs signed by the configured enrollment signer; the status field may be represented in the general CSR contract, but non-enrollment signers do not receive issuance semantics in this part.
- Define issuance as successful status publication, not CSR approval, signer invocation, certificate `NotBefore`, or Enrollment Request approval.
- Capture the server timestamp immediately before recording a successful signing result.
- Publish `status.certificate` and `status.issuedAt` in the same existing CSR status update.
- Keep the existing signing helper private to the CSR service; do not expose a public `CompleteIssuance` or equivalent method.
- Route both manual and automatic enrollment approval through the unchanged CSR approval and signing flow.
- Make repeated signing attempts idempotent: if issued certificate bytes already exist, preserve both the certificate and its original `issuedAt`.
- Make first publication authoritative under concurrency: if another writer has already committed issuance evidence, later attempts must return or preserve the committed result rather than overwriting it.
- If signing or status publication fails, persist neither the new certificate bytes nor `issuedAt`; use the existing failed-condition behavior.
- Reject or ignore client-supplied `issuedAt` values, including values supplied through CSR replacement or approval status updates.
- Do not backfill `issuedAt` for CSRs that already contain certificate bytes.
- Do not add a new database resource, event, public route, approval method, revocation endpoint, or transaction callback.
- Defer signer-filtered CSR inventory. If that capability is needed later, `spec.signerName` is the natural selector field, but adding it is not required to publish issuance metadata.
- Preserve the existing certificate bytes in CSR status so later work can derive the exact enrollment leaf identity.

## Testing Decisions

- Good tests assert the externally visible CSR status, API contract, idempotency, and failure behavior. They do not test private helper names, SQL details, or transaction internals.
- Use the existing CSR service handler as the primary test seam. It already covers approval, signing, status publication, and caller-visible failures.
- Test that a successfully signed enrollment CSR returns non-empty certificate bytes and a non-zero `issuedAt` in the same result.
- Test with an injected deterministic clock so exact timestamps and boundary behavior are reproducible.
- Test that a signing failure leaves certificate bytes and `issuedAt` unset and records the existing failure condition.
- Test that a status-publication failure does not leave a partial certificate-only or timestamp-only CSR.
- Test that retrying an already issued CSR preserves the original certificate bytes and timestamp.
- Test that replacing or approving a CSR cannot create or modify `issuedAt`.
- Test that concurrent issuance attempts cannot replace committed issuance evidence.
- Test that historical CSRs with certificate bytes and no `issuedAt` remain readable and are not modified.
- Test that a non-enrollment-signer CSR does not receive enrollment issuance metadata in this part.
- Exercise store-level persistence where needed to verify atomicity and first-writer behavior without exposing private implementation seams.
- Add API serialization coverage so generated clients round-trip the optional timestamp consistently.
- Prior art is the existing CertificateSigningRequest service, approval, signing, status-update, and selector tests.

## Out of Scope

- The shared CEL runtime and enrollment matching engine (Part A).
- EnrollmentApprovalPolicy persistence and matching (Parts A–B).
- Event-driven Enrollment Request admission and the shared approval transaction (Part C).
- Enrollment revocation, mTLS enforcement, pending-request rejection, device flagging, or certificate renewal behavior (Part E and later).
- Deriving, storing, or exposing the exact leaf identity or certificate extensions beyond retaining the already-issued certificate bytes.
- Backfilling issuance metadata for historical CSRs.
- A new public credential resource or alternate CSR identity.
- Signer-filtered CSR inventory and the `spec.signerName` field selector.
- CLI, UI, end-user documentation, and large-scale reporting (Parts G–H).
- Changing certificate lifetime, signer configuration, approval permissions, or manual approval semantics.

## Further Notes

- Respects ADR 0003 (reuse the enrollment CSR as the credential identity) and ADR 0008 (issuance-based auto-approval window).
- This part intentionally supplies only the issuance evidence required by the existing approval-window design. Revocation and mTLS behavior remain separate decisions.
- A CSR with certificate bytes but no `issuedAt` is a legacy issuance record. Later consumers must represent that state explicitly and fail closed where issuance time is required.
