Status: ready-for-agent

# EDM-4868 Part B — EnrollmentApprovalPolicy resource and persistence

## Problem Statement

Fleet administrators need a tenant-scoped resource for configuring automatic Enrollment Request approval, but Flight Control has no EnrollmentApprovalPolicy resource today. The resource must bind to an existing enrollment certificate, carry the matching and label-seal configuration, expose a server-owned lifetime count, and allow multiple policies for one certificate only when their enabled match domains are provably disjoint. Those are cross-policy invariants: a normal single-resource update can pass validation against a stale sibling set, and an admission decision can otherwise use an outdated policy set. The resource also has to follow Flight Control's established service, store, optimistic-concurrency, event, and status-subresource behavior instead of introducing a parallel resource framework.

## Solution

Add EnrollmentApprovalPolicy as a standard core resource with create, list, get, replace, patch, delete, and status-subresource operations. The route-facing service owns policy validation and event publication. The store owns persistence and atomicity: single-policy writes use the repository's normal typed mutation primitive, while a narrow certificate-locked adapter validates the complete prospective enabled set and provides the locked policy snapshot and atomic count operation needed by the later admission pipeline. The certificate binding is immutable and guarded, status counts are server-owned, and all enabled-set writes serialize on the issuing CSR lock.

## User Stories

1. As a fleet administrator, I want to create an EnrollmentApprovalPolicy, so that I can configure automatic approval for a specific enrollment certificate.
2. As a fleet administrator, I want new policies to default to disabled, so that automatic approval is always an explicit opt-in.
3. As a fleet administrator, I want to select an enrollment certificate by its tenant-local issuing CSR name, so that policy scope matches the credential identity already used by Flight Control.
4. As a fleet administrator, I want certificate selection to be immutable, so that reusing or editing a policy cannot silently move it to another credential.
5. As a fleet administrator, I want to configure a boolean match expression, so that only requests reporting the intended commissioning group can auto-approve.
6. As a fleet administrator, I want to require TPM verification through a separate policy field, so that trust gating is explicit and cannot be confused with agent-reported matching data.
7. As a fleet administrator, I want to define static Device labels and allowed incoming ER label keys, so that automatic approval applies a predictable label seal.
8. As a fleet administrator, I want to configure an optional lifetime approval limit, so that a commissioning credential cannot onboard more devices than intended.
9. As a fleet administrator, I want omitted and zero limits to have distinct meanings, so that unlimited and blocked automatic approval are unambiguous.
10. As a fleet administrator, I want to configure an optional issuance-based approval window, so that a long-lived certificate can allow automatic approval for only an initial commissioning period.
11. As a fleet administrator, I want to list, get, replace, patch, and delete policies, so that I can manage the complete policy lifecycle.
12. As a fleet administrator, I want to read a policy status subresource, so that I can see how many requests the policy has automatically approved.
13. As a fleet administrator, I want ordinary policy writes to require the current resource version, so that concurrent edits cannot silently overwrite each other.
14. As a fleet administrator, I want to keep disabled overlapping drafts, so that I can prepare alternative commissioning groups without making them active.
15. As a fleet administrator, I want multiple enabled policies for one certificate when they are provably disjoint, so that separate groups can receive different static labels.
16. As a fleet administrator, I want overlap rejection to identify the conflicting policy, so that I can fix the right expression.
17. As a fleet administrator, I want lowering an approval limit below the already consumed count to remain valid, so that I can stop future approvals without invalidating history.
18. As a fleet administrator, I want deleting a policy to preserve its count and admission audit history, so that resource deletion cannot erase accountability.
19. As a security officer, I want enabled policies for a certificate to be validated as a complete set under a lock, so that two concurrent writers cannot each pass validation against an outdated sibling.
20. As a security officer, I want an expression to be unable to select another certificate or organization, so that reported data can never widen credential scope.
21. As a security officer, I want policy status and security fields to be server-owned, so that administrators and devices cannot forge accounting or trust state.
22. As a security officer, I want deletion or replacement of an enrollment CSR to be guarded while policy bindings or audit retention require it, so that credential identity cannot be reset through name reuse.
23. As an OT operator, I want policy changes to leave pending and already approved Enrollment Requests untouched, so that administrators can adjust future approvals without rewriting history.
24. As a Flight Control engineer, I want the policy service to follow the repository's focused resource-service convention, so that routes, authorization, validation, and events remain predictable.
25. As a Flight Control engineer, I want single-policy writes to use the repository's normal typed mutation primitive, so that resource-version checks, retries, before/after snapshots, and event data are not reimplemented.
26. As a Flight Control engineer, I want only the cross-policy lock, set validation, and atomic count to form a new internal seam, so that the resource avoids shallow duplicated interfaces.
27. As a Flight Control engineer, I want the admission pipeline to consume a locked policy snapshot rather than learning transaction and lock ordering, so that Part C can own admission decisions without leaking store sequencing.
28. As a Flight Control engineer, I want service and store ownership separated, so that business rules, persistence, and atomicity stay in their established layers.

## Implementation Decisions

- EnrollmentApprovalPolicy is a new standard core resource with explicit API version, kind, metadata, spec, and optional status. It follows the existing tenant/name/resource-version conventions, ListMeta list shape, managed-field sanitization, metadata and label validation, and lowercase plural REST routes.
- The route-facing service exposes the conventional named create, list, get, replace, patch, delete, and status-read operations. It sanitizes untrusted documents, validates administrator-owned fields, rejects protected status input, maps store errors to the existing Status response shape, and emits existing resource lifecycle events.
- The policy spec contains `enabled`, immutable `certificateName`, `requireTPMVerification`, `matchExpression`, static `deviceLabels`, `allowedIncomingLabels`, optional `approvalLimit`, and optional `autoApprovalWindowDays`. The status contains only the server-owned `enrollmentCount`.
- `enabled` defaults to false. `approvalLimit` is omitted for unlimited, zero to block automatic approval, or a nonnegative finite maximum. `autoApprovalWindowDays` is omitted or an inclusive positive value whose day duration fits the service's time representation. Static and incoming label keys and values use the existing resource-label validation rules.
- `certificateName` must resolve to an issued, valid, same-tenant CSR using the configured device-enrollment signer. It is fixed after creation; changing it requires a new policy. The policy does not introduce a new credential identity, fingerprint, or organization field.
- Use the exact CSR name attested by the issued enrollment leaf, not its normalized common name. Policy writes may load the named CSR for validation and locking; this is not ER identity discovery. New-enrollment consumers require the supported signed binding from [ADR 0003](../../docs/adr/0003-enrollment-csr-as-credential-identity.md); a policy reference cannot make a legacy leaf compatible or substitute for authoritative credential-state checks.
- `matchExpression` is synchronously compiled and validated with the Part A enrollment matching engine. Validation rejects non-boolean expressions, unsupported constructs, singleton product-UUID rules, invalid bounds, and expressions that are not provably disjoint from the resulting enabled set.
- Policy writes that can affect the enabled set validate the complete prospective set, not only the submitted policy. Disabled overlapping drafts are allowed. Enabling, creating already enabled, replacing, or patching an enabled expression requires every enabled policy for that certificate to remain provably disjoint.
- Set validation runs while the issuing CSR row is locked. The service supplies the policy-set validator; the store supplies transaction and lock ordering. A conflict or deadlock retries the complete locked operation against fresh state rather than validating a stale set.
- Single-policy create, replace, patch, and server-owned status initialization use the repository's normal typed mutation primitive. The policy store wraps the generic mutation hooks with its typed resource mutation, preserving optimistic concurrency, retry behavior, before/after snapshots, created indication, and event inputs.
- The set-aware operation is a narrow store adapter, not a new general mutation framework. It starts or joins the active transaction, locks the issuing CSR, loads the current enabled set, constructs the prospective set, invokes the service-owned validator, and then persists the target policy through the normal mutation primitive.
- The store exposes a separate internal admission contract for the later admission pipeline: return a transaction-bound locked enabled-policy snapshot, atomically increment the matching policy's enrollment count, and guard enrollment-certificate mutations. It does not evaluate CEL, choose an admission outcome, mutate an Enrollment Request, apply labels, or sign a certificate.
- `LockAdmissionSet` returns the current enabled policies and policy-set revision in the caller's active transaction. It does not return an explicit unlock callback or require the caller to manage lock lifetime.
- `IncrementEnrollmentCount` checks the current limit and count and increments only inside the committed admission transaction. It always increments when an automatic approval commits, including for unlimited policies, and never increments for manual approval. A limit-exhausted result is a distinct store outcome, not a generic mutation error interpreted by string matching.
- `GuardCertificateMutation` prevents deletion, replacement, or name reuse that would break a policy binding, reset a count, or evade retained admission audit while enforcement or retention requires the credential. It does not change renewal or service-client CSR behavior.
- The credential layer also reserves the issued name while its leaf can authenticate or retained enrollment/revocation history requires it, even with no current policy. A still-valid signed binding must never point at a recreated CSR or a replacement leaf.
- The policy table uses the existing tenant/name/resource-version resource shape. Spec and status are stored once in the existing JSONB-style resource columns. There is an index from tenant and certificate name to policies, but no uniqueness constraint on certificate name because multiple disjoint policies are allowed.
- Every returned policy initializes status with `enrollmentCount: 0`. Only server admission logic updates the count. No remaining-count, CSR-side counter, or duplicate accounting field is stored.
- Policy-set changes increment the per-certificate set revision while holding the CSR lock, so queued or final admission work can detect stale evaluations. The physical CSR-side storage for that revision is coordinated with the certificate-extension part; this part owns the revision semantics on policy writes.
- Policy deletion preserves admission audit and counter history through the established tombstone/retention approach. It does not add a Device relationship or foreign key.
- Events use the mutation result and before/after snapshots returned by the store. The service does not independently re-read a just-written policy to discover what changed.
- REST authorization remains tenant-scoped. Policy administration and quota changes require the existing administrator/quota permissions; status reads use policy-status read permission. No caller-provided organization can widen access.
- The service does not expose transaction, lock, validator callback, or admission-decision details through its route-facing interface.

## Testing Decisions

- Good tests assert external behavior through the policy service and its narrow admission-store contract. They survive internal refactors and do not assert generic mutation internals, lock implementation details, SQL text, cache state, or event callback wiring.
- The primary test seam is the route-facing EnrollmentApprovalPolicy service. Table-driven service tests cover create, list, get, replace, patch, delete, status reads, sanitization, validation, immutable certificate binding, resource-version conflicts, server-owned status, error mapping, and lifecycle events.
- Store integration tests exercise the cross-policy behavior that cannot be observed safely through a single-resource fake: CSR-lock serialization, complete prospective-set validation, concurrent enabled writes, disabled-overlap acceptance, conflict retries, policy-set revision changes, count atomicity, limit-exhausted outcomes, and certificate-mutation guards.
- Concurrency tests use deterministic overlapping transactions or the repository's established integration-test techniques rather than sleeps or timing races.
- Count tests verify that automatic-admission commits increment once, unlimited policies still increment, manual approval does not increment, rollback leaves the count unchanged, and replay/idempotency does not double-count.
- Certificate-guard tests cover deletion, replacement, and name-reuse protection when a live policy or retained audit requires the issuing CSR, while confirming unrelated signer flows remain unchanged.
- Event tests use returned before/after and created results; they do not re-read the resource merely to reconstruct the event payload.
- Prior art is the repository's existing focused resource-service handler tests, table-driven store tests, and integration tests for transactional resource behavior.

## Out of Scope

- The shared CEL runtime and enrollment matching engine (Part A).
- The admission transaction, Enrollment Request mutation, label seal, provenance fields, conditions, idempotency ledger, and final exact-one-match execution (Part C).
- CSR issuance-time, revocation, and certificate-extension storage (Part D), and mTLS enforcement or device flagging (Part E).
- TPM challenge and verification machinery (Part F); this part only persists and validates the separate policy gate.
- CLI, UI, end-user documentation, and the 5000-device scale demonstration (Parts G–H).
- Changing the existing EnrollmentRequest, Device, renewal, or service-client behavior.
- Adding a new credential resource, regex matching, arbitrary CEL, per-device policy rules, per-minute or burst enrollment limits, or a second general mutation framework.

## Further Notes

- Respects ADR 0005 (restricted CEL with exact-one-match), the Enrollment auto-approval glossary terms `EnrollmentApprovalPolicy`, `issuing CSR`, `provably disjoint`, `approval limit`, `enrollment count`, `label seal`, and `limit-blocked`, and the approved technical design's service/store ownership rule.
- Part A already defines the matching engine. This part intentionally persists and orchestrates policy resources without duplicating CEL semantics.
- The narrow admission-store contract is justified by two real consumers: policy writes that need certificate-set consistency and the Part C admission transaction that needs a locked snapshot and atomic count. It is not a mock-only seam.
