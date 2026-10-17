Status: ready-for-agent

# EDM-4868 Part C — Event-driven automatic Enrollment Request admission

## Problem Statement

Fleet administrators need Enrollment Requests to approve themselves when exactly one eligible EnrollmentApprovalPolicy matches, but Flight Control currently has only a manual approval path. That path signs a management certificate, creates the same-named Device, and updates the Enrollment Request in separate steps, so it is not safe to reuse unchanged for automatic approval. The new flow must remain event-driven, reuse the existing approval route and event vocabulary, record why a request is pending, apply the label seal exactly once, consume policy quota atomically, and remain idempotent when workers retry. It must also preserve the existing manual approval behavior and avoid introducing a parallel public admission interface.

## Solution

Wire automatic approval to the existing Enrollment Request lifecycle. When an agent submits an Enrollment Request, the service reads available credential details from the already authenticated certificate/context, persists the request with an explicit legacy marker if required details are absent, then emits the existing resource-created event. A worker consumes that existing event, evaluates the current enabled policies for that certificate, records pending diagnostics immediately, and when exactly one policy passes all gates, invokes the same approval operation used by manual approval with an internal automatic source and policy provenance. The existing approval path is extended internally to accept that automatic source; its public REST contract stays unchanged. Manual approval continues to use the authenticated username, while automatic approval records the approving policy in `approvedBy` and keeps structured policy name and resource-version fields for querying and audit.

## User Stories

1. As a fleet administrator, I want an Enrollment Request to be evaluated as soon as it is created, so that eligible devices are admitted without manual action.
2. As a fleet administrator, I want the worker to evaluate only the policies bound to the request’s issuing CSR, so that unrelated credentials cannot affect the decision.
3. As a fleet administrator, I want pending reasons written as soon as evaluation finishes, so that I can see why a request did not auto-approve.
4. As a fleet administrator, I want exactly one matching enabled policy to approve the request, so that the outcome is deterministic.
5. As a fleet administrator, I want zero matches to leave the request pending for manual approval, so that unmatched devices are not rejected or lost.
6. As a fleet administrator, I want multiple matches to leave the request pending with an ambiguity reason, so that no implicit priority chooses a winner.
7. As a fleet administrator, I want one broken policy candidate not to veto another passing policy, so that a single bad expression cannot block an otherwise valid request.
8. As a fleet administrator, I want TPM verification enforced as a separate gate, so that trust is never inferred from agent-reported identifiers.
9. As a fleet administrator, I want the optional issuance-based window enforced during evaluation and final commit, so that a valid long-lived credential can still stop auto-approving after its commissioning window.
10. As a fleet administrator, I want the policy approval limit enforced atomically, so that the final available slot cannot be consumed twice.
11. As a fleet administrator, I want automatic approval to apply the label seal once, so that static administrator labels and explicitly allowed incoming labels are preserved exactly as configured.
12. As a fleet administrator, I want automatic approval to reuse the existing approval path, so that manual and automatic approvals produce the same Device, certificate, and status behavior.
13. As an OT operator, I want automatic approvals to identify the approving policy in `approvedBy`, so that I can tell whether a human or policy approved a device.
14. As an OT operator, I want structured policy name and resource-version fields on the Enrollment Request, so that I can filter and audit automatic approvals without parsing display text.
15. As an OT operator, I want limit-blocked requests to remain pending with the exact quota-only reason, so that I know manual approval is still available.
16. As an OT operator, I want policy changes to reevaluate pending requests, so that raising or removing a limit can unblock eligible devices.
17. As an OT operator, I want report changes and completed TPM verification to reevaluate pending requests, so that newly available evidence can produce an approval.
18. As an OT operator, I want manual approval to keep its current behavior, so that automatic approval does not change the existing human workflow.
19. As a security officer, I want the issuing-CSR binding resolved from authenticated context during ER creation, so that a device cannot select another credential.
20. As a security officer, I want worker retries to be idempotent, so that duplicate events cannot approve twice or double-count quota.
21. As a security officer, I want automatic approval to commit the certificate, Device, Enrollment Request, ledger, counter, and outbox atomically, so that a partial admission is never observable.
22. As a security officer, I want final admission to revalidate the current policy set and quota under lock, so that a stale worker evaluation cannot approve against changed policy state.
23. As a Flight Control engineer, I want to reuse existing resource-created and resource-updated events, so that automatic approval does not require a new event type.
24. As a Flight Control engineer, I want the worker to call the existing approval operation with an internal automatic source, so that we do not add a parallel public admission route.
25. As a Flight Control engineer, I want the shared commit helper to use the repository’s normal typed mutation primitive where appropriate, so that we do not create a second general mutation framework.
26. As a Flight Control engineer, I want the public approval interface unchanged, so that callers are not exposed to transaction, lock, or worker internals.
27. As a Flight Control engineer, I want policy-change events to find pending requests by certificate, so that reevaluation is targeted rather than a global scan.
28. As a Flight Control engineer, I want evaluation diagnostics and final approval reasons mapped consistently, so that pending conditions remain stable across retries.

## Implementation Decisions

- Enrollment Request creation reads credential details, including the exact tenant-local CSR name when present, from the already authenticated certificate/context without an extra CSR identity/details lookup. If required details are absent, persist the ER without them and explicitly mark it as legacy; legacy ERs are ineligible for enrollment approval policies. Missing metadata does not bypass authentication or prevent ER creation, and is not filled from the request body or a database fallback. No separate public binding method is introduced.
- Automatic evaluation is triggered by the existing Enrollment Request lifecycle events and by EnrollmentApprovalPolicy lifecycle events. No new event reason or event type is added for this feature.
- The worker task matches Enrollment Request created and updated events by involved-object kind and reason, and matches policy changes by policy kind and certificate binding. Policy changes find pending Enrollment Requests for the affected certificate.
- The existing `EnrollmentRequestApproved` event remains a post-approval event for downstream work such as enrollment-hook notification; it is not used to trigger evaluation.
- The worker loads the current locked policy set through the Part B admission-store contract and evaluates it with the Part A matching engine. It records per-candidate diagnostics and aggregate pending reasons before attempting approval.
- The worker does not sign a certificate or create a Device directly. When exactly one policy passes all gates, it builds an automatic approval request containing the final label seal, policy name, policy resource version, and automatic source, then invokes the existing approval operation.
- The existing approval operation gains an internal automatic-source path or context value. Its public REST contract, route, and manual behavior remain unchanged.
- Manual approval records the authenticated username in `approvedBy`. Automatic approval records the approving policy as `enrollmentapprovalpolicy/<policy-name>`. Structured `enrollmentPolicyName` and `enrollmentPolicyResourceVersion` fields remain the canonical queryable provenance; no new `approvedByKind` field is added.
- The `Approved` condition distinguishes manual and automatic approval. Automatic approval uses the `AutomaticallyApproved` reason and a message that identifies the approving policy.
- Automatic approval computes the label seal from static device labels plus explicitly allowed incoming Enrollment Request labels, with static values winning, and commits it with replace-labels semantics.
- Automatic approval creates the same-named Device, signs the management certificate, updates Enrollment Request approval and provenance fields, inserts an admission-ledger entry, increments the policy’s enrollment count, and enqueues events/hooks through a transactional outbox in one commit.
- The admission ledger is keyed by a durable admission identity so worker retries and duplicate events return the existing committed result without signing again or incrementing the count again.
- Final admission revalidates the issuing CSR, policy set, policy version, TPM gate, issuance window, quota, and Enrollment Request state under lock before committing. A stale worker evaluation never becomes a final approval by itself.
- The shared commit helper uses the repository’s normal typed mutation primitive for suitable single-resource writes and a narrow multi-resource transaction for cross-resource admission. It does not expose transaction callbacks, lock ordering, or policy evaluation to callers.
- Any signer, Device, ledger, counter, status, or outbox failure rolls back every admission mutation. Certificate bytes are returned only after commit.
- Manual approval does not run CEL, consult a policy limit, increment enrollment count, or create an automatic admission-ledger entry.
- Policy deletion, disablement, or edit does not reject an already approved Enrollment Request or alter an existing Device. It only causes pending requests to be reevaluated.
- Issuance-window expiry, TPM requirements, hook gates, and quota exhaustion are pending outcomes, not Enrollment Request rejections.

## Testing Decisions

- Good tests assert external behavior through the worker task and the existing Enrollment Request approval service. They do not assert transaction internals, lock order, SQL text, or private helper shapes.
- The primary test seam is the automatic-admission worker task: existing event matching, policy evaluation, diagnostics, automatic-source approval, and idempotent retry behavior.
- The existing approval-service seam is tested for manual/automatic source handling, `approvedBy` policy references, structured provenance, label seal, Device creation, status conditions, and event emission.
- Integration tests exercise the full event-to-commit path with the real policy engine and store adapters: created and updated Enrollment Request events, policy-change reevaluation, TPM completion, limit increase/removal, exact-one-match, ambiguity, candidate-error isolation, window boundary, quota exhaustion, rollback, and duplicate-event idempotency.
- Concurrency tests use deterministic overlapping transactions rather than sleeps. They cover final-slot admission, policy updates during evaluation, duplicate worker delivery, and rollback consistency across ER, Device, ledger, count, and outbox.
- Event tests verify that no new event reason is introduced and that the worker consumes the existing resource-created and resource-updated lifecycle events.
- Prior art is the repository’s existing Enrollment Request service tests, worker task tests, and transactional store integration tests.

## Out of Scope

- The shared CEL runtime and matching engine (Part A).
- The EnrollmentApprovalPolicy resource, CRUD service, status subresource, and certificate-locked policy-set store (Part B).
- CSR issuance-time, revocation, and certificate-extension storage (Part D).
- mTLS revocation enforcement, pending-request rejection, and device flagging (Part E).
- TPM challenge and verification machinery (Part F); this part only consumes the server-owned verified condition.
- CLI, UI, end-user documentation, and the 5000-device scale demonstration (Parts G–H).
- Adding a new public admission route, a new public `Admit` method, a new event type, or a new general mutation framework.
- Changing manual approval semantics other than sharing the same atomic commit safety.
- Batching policy-change fan-out or proving large-scale throughput.

## Further Notes

- Respects ADR 0005 (restricted CEL with exact-one-match), ADR 0008 (issuance-based auto-approval window), and the Enrollment auto-approval glossary terms `EnrollmentApprovalPolicy`, `issuing CSR`, `exact-one-match`, `label seal`, `approval limit`, `enrollment count`, `limit-blocked`, and `admission ledger`.
- Part A owns matching semantics, Part B owns policy persistence and locked set state, and this part owns event-driven orchestration and the shared approval commit path.
- The existing resource-created and resource-updated events are sufficient triggers; domain-specific post-approval events remain unchanged.
