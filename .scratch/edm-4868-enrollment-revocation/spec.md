Status: ready-for-agent

# EDM-4868 Part E — Enrollment revocation and affected-device flagging

## Problem Statement

Security officers need to stop a compromised or retired enrollment credential from admitting more devices, but Flight Control currently verifies enrollment certificates only during the normal mTLS chain check. Deleting the issuing CertificateSigningRequest row does not revoke the certificate, pending Enrollment Requests have no revocation-aware rejection outcome, and operators cannot identify automatically onboarded devices that were admitted through a revoked credential. Revocation must take effect without evicting already enrolled devices, stopping management-certificate renewal, or changing service-client behavior.

## Solution

Add an enrollment-only revocation subresource to the existing CertificateSigningRequest. A security officer commits immutable revocation state and durable consequence work in one transaction. The shared agent TLS configuration gains a revocation check that resolves a presented enrollment leaf to its issuing CSR by exact DER fingerprint and rejects revoked or unresolved credentials against the primary database. Enrollment Requests use the issuing-CSR binding already stored by the admission pipeline; this part adds no new CSR verification or authorization interface. Pending Enrollment Requests bound to a revoked CSR become rejected with a reason, and automatically onboarded Devices are flagged within five minutes. Revocation never removes a Device or stops its management-certificate renewal.

## User Stories

1. As a security officer, I want to revoke an enrollment credential, so that it can no longer be used for new enrollment.
2. As a security officer, I want revocation to take effect on the next enrollment handshake, so that there is no continuing acceptance window.
3. As a security officer, I want to supply a revocation reason, so that operators and auditors can understand why the credential was revoked.
4. As a security officer, I want the actor and revocation time recorded by the server, so that request data cannot forge audit provenance.
5. As a security officer, I want repeated revocation calls to be idempotent, so that retries do not create duplicate work or overwrite the original timestamp.
6. As a security officer, I want only enrollment-signer CSRs to be revocable through this subresource, so that management and service-client credentials are not accidentally affected.
7. As a security officer, I want revocation to fail closed when authoritative state is unavailable, so that a database outage cannot silently allow enrollment.
8. As a security officer, I want an unresolved enrollment leaf rejected, so that a certificate that cannot be matched to its issuing CSR cannot bypass revocation.
9. As a security officer, I want the exact issued leaf matched by DER fingerprint, so that reused common names or colliding serial numbers cannot retarget revocation.
10. As a fleet administrator, I want pending Enrollment Requests tied to a revoked credential rejected with a clear reason, so that they do not remain indefinitely pending.
11. As a fleet administrator, I want already approved Enrollment Requests to remain approved, so that revocation does not rewrite completed enrollment history.
12. As a fleet administrator, I want automatically onboarded Devices associated with the revoked credential flagged, so that I can identify the affected fleet.
13. As a fleet administrator, I want Device flags to materialize within five minutes, so that incident response has a bounded operational guarantee.
14. As a fleet administrator, I want manually approved Devices to remain outside the automatic-onboarding flag set, so that flagging reflects the credential-driven automatic admissions it was designed to identify.
15. As an OT operator, I want revoked enrollment to explain that existing management access is not revoked, so that I do not mistake flagging for eviction.
16. As an OT operator, I want management-certificate renewal to continue after enrollment revocation, so that already enrolled devices remain manageable.
17. As an OT operator, I want service-client authentication unchanged, so that revoking an enrollment credential does not break control-plane integrations.
18. As an auditor, I want the issuing CSR, Enrollment Request, policy provenance, and same-named Device to remain traceable, so that I can reconstruct which automatic admissions used the credential.
19. As an auditor, I want historical admissions without a trustworthy issuing-CSR binding represented as legacy unknown, so that the system does not silently link them to a revoked credential.
20. As an API consumer, I want to read revocation state from the normal CSR representation, so that I do not need a separate credential resource.
21. As an API consumer, I want an idempotent revocation operation with clear validation errors, so that automation can safely retry or report invalid targets.
22. As a Flight Control engineer, I want the issuing CSR to remain the credential identity, so that revocation does not introduce a second public identifier.
23. As a Flight Control engineer, I want the Enrollment Request’s stored issuing-CSR binding to be the approval-time input, so that Part E does not duplicate or verify CSR binding.
24. As a Flight Control engineer, I want the TLS check installed at the shared agent termination seam, so that HTTP and gRPC enrollment paths receive the same enforcement.
25. As a Flight Control engineer, I want the existing enrollment identity cache to cache identity only, so that it cannot bypass revocation.
26. As a Flight Control engineer, I want established connections rechecked before enrollment work is committed, so that a connection accepted before revocation cannot complete admission afterward.
27. As a Flight Control engineer, I want durable consequence work instead of a new event type, so that recovery does not depend on a domain event remaining in a queue.
28. As a Flight Control engineer, I want revocation and consequence scheduling committed atomically, so that a revoked CSR can never be observable without its follow-up work.
29. As an SRE, I want backlog and oldest-revocation metrics, so that I can detect failures to meet the five-minute flagging bound.
30. As an SRE, I want consequence work to resume after a crash, so that a worker restart does not leave flags or pending-request rejections incomplete.

## Implementation Decisions

- Represent revocation as a nested CSR status subresource, not a new top-level credential resource.
- Store immutable server-owned `revokedAt`, `revokedBy`, and administrator-supplied reason values; optionally store a server-owned flagging-completion timestamp.
- Expose an idempotent revocation operation on the existing CSR resource. The request supplies only the reason; actor and time come from authenticated context and the server clock.
- Require the configured enrollment signer and an issued certificate before revocation is allowed.
- Preserve the existing CSR approval and issuance history; revocation adds an enrollment-credential condition rather than rewriting issuance state.
- Resolve a presented enrollment leaf to its issuing CSR using an exact DER fingerprint lookup against the retained issued certificate bytes. This is a lookup, not CSR verification.
- Do not use common name, issuer, or serial number as the sole revocation identity.
- Query authoritative primary-database revocation state on every enrollment handshake, including resumed sessions.
- Fail closed for revoked credentials, unresolved leaf-to-CSR mappings, and authoritative-store unavailability.
- Install the check at the shared agent TLS termination configuration so HTTP and gRPC inherit the same behavior.
- Apply the check only to enrollment-signer leaves; management, management-renewal, and service-client paths retain their existing behavior.
- Keep the existing enrollment identity cache for identity only. It must not cache an unrevoked decision.
- Recheck revocation in Enrollment Request create, update, approval, TPM completion, and final admission paths so established connections cannot complete new enrollment after revocation.
- Use the issuing-CSR binding stored on the Enrollment Request by the admission pipeline. Do not introduce a new public binding method or a new CSR verification step.
- Project pending Enrollment Requests bound to a revoked CSR as rejected on read and block their approval while durable materialization is pending.
- Persist the rejected Enrollment Request condition through the consequence worker using the repository’s normal typed mutation behavior.
- Flag automatically onboarded Devices using the existing same-name Enrollment Request-to-Device relationship and automatic-approval provenance.
- Do not flag manually approved Devices in this part.
- Do not remove Devices, stop management-certificate renewal, quarantine Devices, or change service-client authentication.
- Commit immutable revocation state and durable consequence work together in one narrow transaction.
- Use a durable revocation-work record and existing worker/task infrastructure; no new domain event type is required.
- Process consequence work idempotently in bounded batches, with recovery after worker restarts.
- Block deletion or name reuse of an enrollment CSR while a policy, retained Enrollment Request history, or revocation record depends on it.
- Represent historical admissions whose issuing CSR cannot be trustworthily reconstructed as `LegacyUnknown`; do not retroactively bind them to a revoked credential.
- Do not implement CRL or OCSP distribution.
- Do not provide un-revocation in this part.
- The five-minute bound is an operational maximum for durable Device-flag materialization, not an admission grace period.

## Testing Decisions

- Good tests assert externally visible TLS, CSR, Enrollment Request, and Device behavior. They do not test private helper names, SQL text, lock order, or queue internals.
- Use a real mTLS integration seam for handshake behavior: unrevoked enrollment, revoked enrollment, unresolved leaf, authoritative-store unavailability, session resumption, and non-enrollment signers.
- Test the CSR service for revocation validation, idempotency, immutable fields, permission handling, wrong-signer rejection, and unissued-certificate rejection.
- Test Enrollment Request behavior using the stored issuing-CSR binding: immediate rejection projection, blocked approval, unchanged approved requests, and legacy-unknown handling.
- Test final admission concurrency so revocation committed before admission blocks the admission, while an admission already committed remains enrolled and is flagged.
- Test the consequence worker for pending-request rejection, Device flagging, batching, retry, duplicate delivery, and crash recovery.
- Test that automatically onboarded Devices receive the revocation flag and that manually approved Devices do not.
- Test that management-certificate renewal and service-client paths remain unchanged.
- Exercise store-level persistence for atomic revocation-plus-work commit, first-writer wins, and name-retention guards.
- Add API serialization coverage for the nested revocation status and generated clients.
- Prior art is the existing CSR service, Enrollment Request service, Device service, mTLS middleware, worker task, and transactional store tests.

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
- Reconstructing legacy admissions with unknown issuing-CSR bindings.
- Signer-filtered CSR inventory.
- A new general mutation framework or transaction callback exposed to callers.

## Further Notes

- Respects ADR 0003 (reuse the enrollment CSR as the credential identity) and ADR 0004 (enforce enrollment revocation at mTLS without eviction).
- Part C owns storing the issuing-CSR binding on Enrollment Request creation. This part consumes that binding for revocation consequences and adds no CSR verification step.
- The TLS barrier’s fingerprint lookup identifies which already-issued CSR corresponds to the presented leaf; it does not re-verify the CSR or the certificate chain, which Go’s existing mTLS configuration already handles.
- Revocation is admission control and identification, not eviction. Existing management access remains governed by its existing certificate and authentication paths.
