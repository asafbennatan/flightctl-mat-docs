Status: ready-for-agent

# EDM-6476 — Add enrollment CSR revocation API

Source: Jira EDM-6476 (fetched 2026-11-08). Parent epic: EDM-6303 — Enrollment
Certificate Trust Hardening. Design reference: flightctl/design-docs PR #61.

## Story

As a security officer, I want to revoke an enrollment credential through the
existing CSR API, so that I can disable a compromised credential without
evicting already-enrolled devices.

## Acceptance Criteria

1. `POST /api/v1/certificatesigningrequests/{name}/revocation` accepts only a
   nonblank, bounded reason for an issued, same-tenant enrollment-signer CSR.
2. Revocation metadata is exposed through nested `status.revocation` on the
   existing CSR GET response; no separate revocation GET route is introduced.
3. The API records server-owned actor, time, reason, and flagging progress and
   rejects caller-supplied security metadata.
4. Revocation commits durable deny, audit, and outbox state before returning
   success.
5. Renewal and service-client CSR targets are refused without mutation.
6. Management-certificate renewal and service-client issuance remain
   independent and unchanged.
7. Generated clients, OpenAPI, RBAC, tenant scoping, and actionable
   validation/conflict errors are covered by tests.

## Review scope for this branch

This branch delivers the EDM-6476 API surface plus the revocation-enforcement
slice. The approved-CSR mTLS slice landed in #3815 (be72f0a07); this branch
adds the revocation-denial slice on top of it:

- Revocation denial during enrollment authentication when the issuing CSR has
  `status.revocation` set. Allow decisions always cross the authoritative CSR
  lookup, so no positive status-cache entry exists to invalidate.
- The enrollment status cache remains a deny/missing cache only; revocation
  invalidation hooks are therefore not part of this change.

Not part of this branch (do not report as missing):

- Pending Enrollment Request rejection/projection and approval blocking.
- Automatic-onboarding Device flagging and the five-minute materialization
  bound.
- Consequence-worker processing (pending-request rejection, device flagging),
  batching, retry, crash recovery, and backlog/oldest-revocation metrics.
- Revocation rechecks in Enrollment Request create/update/approval/TPM/final
  admission paths.
- Delete/name-reuse guards for CSRs with retained revocation history.
- mTLS integration/session-resumption tests and consequence-worker tests.

## Design decisions for this branch

- `status.revocation.flaggingCompletedAt` is the nullable flagging-progress
  marker required by AC 3; the consequence worker that sets it is delivered
  separately.
- AC 4's durable state is the `EnrollmentCredentialRevoked` event row, written
  in the same transaction as `status.revocation` and published to the existing
  task queue after commit. Consequence work is event-driven through the
  existing worker/queue and checkpoint mechanism; no separate outbox or
  work-record table is introduced. This matches the repository's established
  DB-write + event + queue pattern used by other workloads.
- Event and generic stores join the transaction carried by the context
  (`store.DB`) so the audit record commits or rolls back with the revocation;
  integration tests cover the rollback path.
- The revocation request body rejects unknown fields, so clients cannot supply
  `revokedBy`, `revokedAt`, or `flaggingCompletedAt`.
- The shared strict-JSON decode helper is also used by the existing enrollment
  approval route; its behavior is unchanged.
- The raw request reason is bounded before trimming, and the enrollment-signer
  and issued-certificate gates run before the idempotent replay return.
- The audit event actor uses the documented `user:<name>` prefix.
- Legacy enrollment credentials whose spec signer changed are still revocable
  when the retained certificate carries the enrollment-signer extension; this
  widening is intentional so credentials issued before a signer migration stay
  revocable.
- `Revoke` loads the current CSR inside the caller's transaction and uses its
  `metadata.creationTimestamp` and resource version for the compare-and-swap.
  A concurrent delete/recreate surfaces as a conflict, or as an idempotent
  success when the current row is already revoked; no caller-supplied identity
  is trusted.

## Parent specs (symlinked into this worktree)

- `.scratch/edm-4868-enrollment-revocation/spec.md`
- `.scratch/edm-4868-enrollment-revocation-mtls/spec.md`
