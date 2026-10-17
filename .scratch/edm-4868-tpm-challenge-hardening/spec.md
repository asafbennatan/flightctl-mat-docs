Status: ready-for-agent

# EDM-4868 Part F — Existing TPM challenge hardening

## Problem Statement

Flight Control already verifies TPM Enrollment Requests through an out-of-band gRPC challenge: Enrollment Request creation verifies the TCG certificate chain and leaves the TPM condition waiting for an activate-credential challenge, and the existing gRPC stream creates, validates, and commits that challenge. The missing guarantees are around ownership and timing. The gRPC path proves only that the connection presented a valid client-certificate chain; it does not prove that the credential on that connection is the credential that created the named Enrollment Request. The stream also loads the Enrollment Request before generating the challenge and writes status after the response, so a replaced CSR or newer status can race the commit. Finally, an enrollment credential can be revoked while a challenge is in flight.

Replacing the existing TPM machinery would duplicate a working flow and expand the review surface. The required change is to harden the existing flow so a completed challenge can only mark the exact CSR, for the exact Enrollment Request, created under the exact authenticated enrollment credential, and only while that credential remains unrevoked.

## Solution

Keep the existing Enrollment Request TCG-chain verification, out-of-band gRPC challenge protocol, condition types, and client protocol behavior. Before starting a challenge, read the mTLS leaf's issuer-attested credential binding under the enrollment-signer and organization rules and require it to match the binding stored on the named Enrollment Request. Do not discover identity by searching certificate inventory. Capture the Enrollment Request version and exact management-certificate CSR bytes used to generate the challenge. After the challenge response is checked, use one transactional status mutation that reloads the current Enrollment Request and, within that same mutation, confirms its version, CSR, credential binding, challenge-eligible condition, and unrevoked authoritative credential state before transitioning the existing TPM condition to verified. Invalid signed identity, a revoked or missing credential, mismatched or stale evidence, or unavailable state prevents the verified transition without changing the public challenge protocol. Legacy enrollment leaves need replacement under the shared compatibility boundary.

## User Stories

1. As a fleet administrator, I want the existing out-of-band TPM challenge to remain the verification mechanism, so that enrollment behavior and agent compatibility do not change.
2. As a fleet administrator, I want a TPM challenge to complete only for the Enrollment Request created by the same enrollment credential, so that one valid credential cannot answer another credential's pending request.
3. As a fleet administrator, I want the challenge to remain bound to the exact CSR used to generate it, so that replacing an Enrollment Request during the challenge cannot transfer verification to a different key.
4. As a fleet administrator, I want successful TPM completion to preserve the existing condition and event behavior, so that policy evaluation and the agent see the same status transition as today.
5. As a fleet administrator, I want an actual failed TPM challenge to retain the existing failed-condition behavior, so that operators can still distinguish a TPM proof failure from a credential or concurrency error.
6. As a security officer, I want the gRPC path to enforce the same enrollment-signer and organization rules as Enrollment Request creation, so that gRPC is not a weaker authentication route.
7. As a security officer, I want the gRPC request to continue carrying only the Enrollment Request name, so that client-supplied credential identifiers cannot influence authorization.
8. As a security officer, I want the credential binding read from the authenticated leaf's issuer-controlled signed identity, so that common names, serial collisions, or request-supplied names cannot redirect the binding.
9. As a security officer, I want missing, invalid, duplicate, conflicting, or unsupported signed identity rejected, so that unknown or ambiguous credential evidence cannot complete TPM verification.
10. As a security officer, I want revocation checked inside the same mutation that sets `TPMVerified=True`, so that a credential revoked during a challenge cannot finish that challenge as verified.
11. As a security officer, I want revocation, credential mismatch, and stale-state failures to leave the TPM condition unverified, so that the status never overstates TPM proof.
12. As a security officer, I want authoritative-state failures to fail closed, so that a database outage cannot become an implicit TPM pass.
13. As a security officer, I want all final authorization checks and the verified transition in one compare-and-set-style status mutation, so that concurrent challenge writers cannot both claim success or overwrite newer Enrollment Request status.
14. As a security officer, I want only the server-verified TPM condition consumed by approval policy, so that device-reported data can never impersonate TPM proof.
15. As a security officer, I want no second TPM verifier, so that the existing chain and activate-credential implementation remains the single authoritative implementation.
16. As an OT operator, I want credential and revocation errors reported distinctly from TPM proof failures, so that I can tell whether to fix the TPM or investigate the credential.
17. As an OT operator, I want existing agents to continue using the same gRPC method and messages, so that the hardening does not require an agent upgrade or protocol migration.
18. As an OT operator, I want a replaced Enrollment Request to require a new challenge, so that a retry after replacement has clear, deterministic behavior.
19. As an auditor, I want the verified condition to identify the exact Enrollment Request transition rather than a generic certificate result, so that admission history remains traceable.
20. As a Flight Control engineer, I want the HTTP and gRPC enrollment paths to share signed-identity and authoritative credential-state rules, so that signer, organization, binding, and retained-leaf checks cannot drift apart.
21. As a Flight Control engineer, I want the status commit to use the repository's normal typed mutation behavior, so that the feature does not introduce a new general transaction framework.
22. As a Flight Control engineer, I want the challenge handler to remain the primary seam, so that tests exercise the externally visible gRPC behavior rather than private helpers.
23. As a Flight Control engineer, I want the existing TPM status update event to drive later policy evaluation, so that no duplicate event reason or worker trigger is added.

## Implementation Decisions

- Keep the existing Enrollment Request TCG-chain verification and the existing out-of-band gRPC activate-credential challenge as the only TPM verification path.
- Do not add a new TPM service, verifier, challenge protocol, public API, gRPC method, request field, event reason, or protocol migration. Obtaining a compatible enrollment credential under the shared signed-identity boundary is still required.
- Continue to authenticate the challenge from the mTLS peer certificate rather than a request-supplied credential identifier.
- Apply the existing enrollment authentication rules to the gRPC challenge: the leaf must be signed by the configured enrollment signer and carry or inherit the same organization semantics used by Enrollment Request creation.
- Reuse the HTTP enrollment path's issuer-attested credential binding rules from [ADR 0003](../../docs/adr/0003-enrollment-csr-as-credential-identity.md); extract shared internal code only where it removes duplication without creating a new public interface.
- Read the exact enrollment credential CSR name from trusted leaf/context with no CSR identity-discovery read. Reject missing, malformed, duplicate, conflicting, or unsupported metadata with no legacy database fallback. The separate Part E authoritative state barrier uses that tenant/name to validate existence, issuance, non-revocation, and the exact retained issued leaf.
- Require the credential CSR binding stored on the Enrollment Request at creation to equal the attested binding from the gRPC peer certificate in the same authenticated tenant.
- Do not match credentials by common name, organization name alone, serial number, or client-supplied CSR name.
- At challenge start, require the Enrollment Request to be pending and its existing TPM condition to be in the challenge-required state; already-verified requests and requests that failed initial TCG verification retain the current failure behavior.
- Capture the Enrollment Request resource version and an exact identity of the CSR bytes used to generate the challenge.
- Do not re-run the Enrollment Request CSR chain check during the gRPC challenge; the existing create-or-replace verification owns that check.
- Commit success through one narrow, transactional Enrollment Request status mutation that reloads the current object and verifies the expected resource version, exact CSR identity, issuing-CSR binding, organization, challenge-eligible condition, and authoritative unrevoked credential state before changing the condition.
- Preserve unrelated current status fields and conditions during the TPM transition; do not write a stale full-status snapshot over a newer status.
- Emit the existing Enrollment Request resource-updated event only after the TPM status mutation commits successfully. The admission worker treats that event as its normal re-evaluation trigger and reloads current state; no TPM-specific event reason is added.
- Do not split the final guards into a separate revocation lookup followed by a status write; that would reintroduce a check-then-write race.
- Treat invalid signed identity, missing or revoked credentials, mismatched evidence, stale state, and authoritative-state unavailability as terminal challenge errors; do not set `TPMVerified=True`.
- Do not mislabel revocation, credential mismatch, or stale-state errors as TPM proof failures. Actual incorrect challenge responses retain the existing TPM challenge-failed condition.
- Rely on the existing Enrollment Request status-update event to make completed TPM verification visible to later admission evaluation.
- Keep the existing management-certificate TPM verifier separate; this part changes only the Enrollment Request challenge path.
- Pending Enrollment Requests created without a trustworthy issuing-CSR binding fail closed and are not retroactively bound; operators must recreate such requests after the binding behavior is available.

## Testing Decisions

- Good tests assert externally visible gRPC responses, Enrollment Request status, events, and authorization outcomes. They do not test private helper names, SQL text, transaction internals, or lock order.
- Use the existing TPM challenge gRPC handler as the primary service seam, backed by real enrollment certificates and the real Enrollment Request store for integration coverage.
- Add mTLS integration coverage for the complete handshake and stream: a matching enrollment credential succeeds, a different valid enrollment credential is rejected, and a non-enrollment-signer certificate is rejected.
- Test organization isolation so a credential from one organization cannot challenge an Enrollment Request in another organization.
- Test signed credential binding for missing, malformed, duplicate, conflicting, unsupported, or cross-tenant metadata, legacy leaves and requests without a binding, and common-name or serial collisions. Confirm no certificate-inventory discovery fallback; separately test missing records and issued-leaf mismatch at authoritative state barriers.
- Test the successful path to ensure the existing verified condition, reason, message, and status-update event remain unchanged.
- Test existing precondition behavior for a missing condition, an already-verified request, and a request whose initial TCG verification failed.
- Test an actual wrong challenge secret to ensure it still produces the existing TPM challenge-failed condition rather than the new authorization or concurrency errors.
- Test a CSR or resource-version replacement between challenge generation and response to ensure the new CSR is not marked verified and the client receives a deterministic error.
- Test concurrent challenge completion so only one writer can commit success and later writers cannot overwrite newer status with a stale snapshot.
- Test that a successful verified transition emits the existing resource-updated event and causes policy re-evaluation, while a failed final mutation emits no success event.
- Test revocation before challenge start and revocation during an in-flight challenge; both must cause the single final mutation to reject `TPMVerified=True`.
- Test authoritative-store unavailability to ensure the challenge fails closed.
- Test that the agent's existing gRPC request and response messages require no protocol change.
- Prior art is the existing Enrollment Request TPM gRPC handler tests, enrollment authentication middleware tests, Enrollment Request service and store tests, and revocation integration tests.

## Out of Scope

- The shared CEL runtime and enrollment matching engine (Part A).
- EnrollmentApprovalPolicy persistence and policy-set behavior (Part B).
- Event-driven automatic admission and the shared approval transaction (Part C).
- CSR issuance metadata (Part D).
- Enrollment revocation state, TLS enforcement, pending-request rejection, and affected-device flagging (Part E).
- Replacing or redesigning the TPM chain verification, activate-credential challenge, or gRPC protocol.
- Verifying the enrollment credential CSR; this part only reads issuer-attested identity, compares bindings, and consumes authoritative credential-state checks.
- Adding a new public authorization interface, credential resource, event type, or general transaction framework.
- Changing management-certificate TPM verification, certificate issuance, certificate lifetime, or certificate renewal.
- Backfilling issuance or credential bindings for historical Enrollment Requests.
- CLI, UI, end-user documentation, and the 5000-device scale demonstration (Parts G–H).

## Further Notes

- Part C stores the issuing-CSR binding when an Enrollment Request is created; this part consumes that binding.
- Part D supplies signed credential identity, and Part E supplies authoritative credential-state barriers. This part consumes both at challenge start and checks state again inside the verified-transition mutation rather than reimplementing them.
- Issuer-attested identity is read without a discovery query; it does not verify the Enrollment Request CSR, replace the existing TCG-chain verification, or prove current record existence/non-revocation. The gRPC stream and HTTP enrollment share the same legacy-credential rejection boundary.
- The gRPC request continues to name only the Enrollment Request. Credential identity comes exclusively from the authenticated mTLS connection.
