Status: ready-for-agent

# EDM-4868 Part D — CSR issuance metadata and signed credential binding

## Problem Statement

Enrollment approval policies need a durable, server-owned time at which an enrollment certificate was issued, but Flight Control currently publishes only the signed certificate bytes on the enrollment credential CertificateSigningRequest. Enrollment Request creation also needs the exact tenant-local CSR name without adding a database read to discover identity. The existing signer normalizes common names, so the common name is not exact resource-name metadata. The working signing and approval route must remain in place, while historical certificates without the new evidence must be distinguishable from compatible credentials.

## Solution

Extend the existing CertificateSigningRequest status contract with an optional, read-only `issuedAt` timestamp and have the existing enrollment signer attest the exact issuance resource name in a reserved signed leaf extension. Publish the resulting certificate bytes and `issuedAt` together in one server-owned status update. The timestamp is taken from the server clock at issuance publication, is immutable once committed, and is not backfilled. Consumers read the binding from the authenticated leaf/context, without a CSR identity-discovery read or legacy lookup fallback; separate authoritative revocation and missing-state checks remain mandatory. No new approval route, event type, signer flow, public credential resource, or client-visible mutation path is introduced.

## User Stories

1. As a fleet administrator, I want an enrollment-signer CSR to record exactly when its certificate was issued, so that policy approval windows have a durable starting point.
2. As a fleet administrator, I want issuance time to be server-owned, so that a device cannot influence when its commissioning window starts.
3. As a fleet administrator, I want issuance time recorded only after the certificate is successfully published, so that a signing failure does not start an approval window.
4. As a fleet administrator, I want issuance time to remain stable across retries and status reads, so that repeated worker or client actions cannot restart a policy window.
5. As a fleet administrator, I want the existing approval/signing flow and certificate lifetime preserved while issuance adds signed identity, so that the compatibility change does not introduce a second issuance route.
6. As a fleet administrator, I want historical CSRs to remain readable and the new-enrollment compatibility boundary to be explicit, so that I can obtain a newly issued compatible credential without rewriting issuance history.
7. As a fleet administrator, I want historical CSRs without issuance metadata to be visibly incomplete rather than approximated, so that policy evaluation fails closed instead of using a fabricated time.
8. As a security officer, I want certificate bytes and issuance time published atomically, so that a CSR can never expose one half of issuance evidence without the other.
9. As a security officer, I want `issuedAt` to be immutable, so that changing policy history or CSR status cannot move an approval window.
10. As a security officer, I want client-supplied `issuedAt` values to be rejected or ignored, so that only the control plane can create issuance evidence.
11. As a security officer, I want concurrent signing attempts to preserve the first committed issuance result, so that duplicate work cannot produce two issuance truths.
12. As a security officer, I want signing failures to leave both certificate bytes and issuance time unset, so that no partial issuance evidence is persisted.
13. As a security officer, I want the exact issued certificate bytes retained on the CSR, so that authoritative state checks can compare the presented leaf without using a fingerprint search to discover its CSR name.
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
24. As a Flight Control engineer, I want existing CSR validation and approval behavior preserved except for reserved-identity injection rejection and the explicit compatibility boundary, so that this change does not alter unrelated semantics.
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

### Issuer-attested credential binding

- Derive the exact tenant-local `metadata.name` from the authoritative CSR being issued, through `SignRequest.ResourceName()`, before common-name normalization. The name remains the sole primary credential identity; the extension is evidence for that name, not another resource or identifier.
- Add exactly one issuer-controlled, non-critical signed enrollment-identity extension to the enrollment leaf. Reject caller-supplied occurrences of that reserved extension in CSR extension requests, even when their value matches the resource name; never copy or override them silently. Other signers do not acquire enrollment identity semantics.
- Use a versioned DER payload: `SEQUENCE { version INTEGER, csrName UTF8String }`, with version `1` and the exact valid resource name. Reject empty or invalid names, unsupported versions, wrong types, malformed DER, trailing data, and duplicate occurrences, including identical duplicates. Do not normalize or infer the name from the certificate common name, serial, HTTP fields, or Enrollment Request body.
- Reserve a dedicated project extension OID before implementation; this document does not allocate or claim a registered OID. The public signer currently uses `1.3.6.1.4.1.99999.1.1`, `.2`, and `.3` for signer, organization, and device fingerprint respectively. Do not reuse those OIDs or assume an adjacent value is registered. Finalize the reserved OID and codec together before producing compatible credentials.
- Authenticate the chain and configured enrollment signer, and apply the existing validated organization rules, including default-tenant handling. Reject conflicting or ambiguous signer, organization, or identity metadata; a signed name cannot override the authenticated tenant. Only server-established leaf/context evidence is accepted.
- Before status publication, verify that the resulting signed leaf carries exactly the authoritative resource's binding and expected tenant/signer. Publish those final bytes and immutable `issuedAt` atomically; failed signing, binding validation, or publication exposes neither new field. Concurrent attempts preserve the first committed leaf and time.
- Enrollment Request creation extracts this binding from the trusted leaf/context and persists it. It must not search certificate inventory, compare candidates to discover a name, or add a separate CSR identity lookup. The primary-state barriers in [ADR 0004](../../docs/adr/0004-enrollment-revocation-at-mtls-without-eviction.md) use the already-attested tenant/name; required database reads and ER persistence are not removed.
- At those authoritative state barriers, validate existence, enrollment signer, issuance, and non-revocation using the attested or previously stored tenant/name. When an enrollment leaf authenticates the operation, also compare its exact DER to the retained issued leaf in that same keyed check. Worker or administrator approval consumes the protected stored binding, not a new enrollment leaf from its caller. Missing or inconsistent state fails closed; none of these checks discovers identity by fingerprint or replaces chain validation.
- Keep the issued CSR name durably reserved while its credential can authenticate or policy, enrollment-history, or revocation retention requires it. Deletion, replacement, and recreation must not retarget a signed binding, reset issuance time, or change the committed leaf.

### Compatibility boundary

- This proposed contract replaces the parent design's common-name/candidate lookup and legacy identity-recovery alternatives, as recorded in [ADR 0003](../../docs/adr/0003-enrollment-csr-as-credential-identity.md). Parent design/PRD/testplan references are historical input where they differ; they are not implicit compatibility exceptions or evidence of approval of this amendment.
- Certificates without the required supported signed identity are incompatible with new enrollment operations, including on existing connections and resumed sessions. Reject them without a CN, serial, request-body, or database-discovery fallback. This is a deliberate change from accepting historical enrollment certificates, not a claim that current code already rejects them.
- Historical CSRs remain readable; do not backfill `issuedAt`, mutate an already-issued leaf, or re-sign an issued CSR to retrofit identity. Obtain a compatible newly issued enrollment credential under a new CSR name and recreate pending requests that lack a trustworthy binding.
- Historical admissions whose binding cannot be trustworthily reconstructed remain `LegacyUnknown`. Do not infer it from management certificates. Existing admitted devices, their management-certificate renewal, and non-eviction semantics are unchanged.
- Rollout must align enrollment issuers and all HTTP/gRPC enrollment readers on this contract. Old servers do not enforce the new boundary; a mixed or rolled-back deployment must not claim these guarantees.

### Public implementation context

At Flight Control commit `4d5138cb52e00c83b342b7fabd84424488bd2c89`, [the enrollment signer](https://github.com/flightctl/flightctl/blob/4d5138cb52e00c83b342b7fabd84424488bd2c89/internal/crypto/signer/signer_device_enrollment.go) compares normalized common names and can access `SignRequest.ResourceName()`; it does not issue dedicated exact CSR-name metadata. [The signer helpers](https://github.com/flightctl/flightctl/blob/4d5138cb52e00c83b342b7fabd84424488bd2c89/internal/crypto/signer/common.go) encode existing string extensions, and [the signer chain](https://github.com/flightctl/flightctl/blob/4d5138cb52e00c83b342b7fabd84424488bd2c89/internal/crypto/signer/signer.go) supplies signer and organization options before [the internal CA](https://github.com/flightctl/flightctl/blob/4d5138cb52e00c83b342b7fabd84424488bd2c89/internal/crypto/internal_ca.go) signs the leaf. These are reuse points, not evidence that the new payload or checks already exist.

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
- Test that issuance signs the exact resource name, including two distinct names that normalize to the same common name, and rejects reserved-extension injection, missing authoritative resource names, and mismatched final leaf bindings before publication.
- Test supported identity decoding and rejection of missing, malformed, duplicate, conflicting, unsupported, wrong-signer, and cross-tenant metadata. Confirm failures do not fall back to certificate inventory or request-supplied names.
- Test ER creation through the authenticated leaf/context seam: the stored binding is the signed name and identity extraction performs no CSR discovery read. Keep separate state-barrier tests for missing/revoked records, unavailable state, and presented-leaf/issued-byte mismatch.
- Test name reservation across attempted deletion, replacement, and recreation, including credentials with the same normalized CN. Reusing a name must not retarget a policy, history, or revocation relationship.
- Test legacy credentials without signed identity failing new enrollment, historical admissions remaining `LegacyUnknown`, and unchanged management-certificate behavior.
- Exercise store-level persistence where needed to verify atomicity and first-writer behavior without exposing private implementation seams.
- Add API serialization coverage so generated clients round-trip the optional timestamp consistently.
- Prior art is the existing CertificateSigningRequest service, approval, signing, status-update, and selector tests.

## Out of Scope

- The shared CEL runtime and enrollment matching engine (Part A).
- EnrollmentApprovalPolicy persistence and matching (Parts A–B).
- Event-driven Enrollment Request admission and the shared approval transaction (Part C).
- Enrollment revocation, mTLS enforcement, pending-request rejection, device flagging, or certificate renewal behavior (Part E and later).
- A second public credential identity or resource, or a certificate-inventory identity-discovery fallback.
- Backfilling issuance metadata for historical CSRs.
- A new public credential resource or alternate CSR identity.
- Signer-filtered CSR inventory and the `spec.signerName` field selector.
- CLI, UI, end-user documentation, and large-scale reporting (Parts G–H).
- Changing certificate lifetime, signer configuration, approval permissions, or manual approval semantics beyond the explicit credential compatibility boundary.

## Further Notes

- Respects ADR 0003 (reuse the enrollment CSR as the credential identity) and ADR 0008 (issuance-based auto-approval window).
- This part supplies issuance evidence and issuer-attested credential binding. Revocation-state storage and enforcement remain separate decisions; signed identity does not establish current non-revocation or record existence.
- A CSR with certificate bytes but no `issuedAt` is a legacy issuance record. Later consumers must represent that state explicitly and fail closed where issuance time is required.
