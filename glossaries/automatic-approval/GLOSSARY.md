# Automatic approval

This context describes the policies that automatically approve Enrollment Requests.

## Language

**Reported identifiers** — Device-supplied facts on an Enrollment Request, such as serial and product identifiers; they are policy-matching inputs, not trust evidence.

**EnrollmentApprovalPolicy** — The administrator resource defining automatic approval rules for exactly one enrollment certificate.

**Match expression** — A restricted boolean policy expression over reported identifiers; it never evaluates certificate identity or TPM status.

**Policy set** — The enabled EnrollmentApprovalPolicies that share one enrollment certificate and are evaluated together under exact-one-match.

**Exact-one-match** — The runtime requirement that exactly one enabled policy for the credential passes; zero or multiple matches leave the request pending with a reason.

**Provably disjoint** — The requirement that enabled policies sharing a certificate have match expressions whose overlap is statically provable to be empty.

**Automatic approval** — Server-side approval of an Enrollment Request when the credential, exactly one matching enabled policy, all required gates, and quota checks pass.

**Policy provenance** — The policy name and version recorded when a policy causes an automatic admission.

**Label seal** — The one-time label assignment at automatic approval: static administrator labels plus explicitly allowed incoming keys, with static values winning.

**Static device labels** — Administrator-defined labels a policy always applies at automatic approval.

**Allowed incoming labels** — Exact Enrollment Request label keys an administrator explicitly permits through the label seal; unlisted keys are dropped.

**Approval limit** — An optional per-policy lifetime maximum of automatic approvals; omitted means unlimited and zero blocks automatic approval.

**Enrollment count** — The server-owned number of committed automatic approvals under a policy; it always increments and never resets.

**Auto-approval window** — An optional per-policy number of days after enrollment certificate issuance during which automatic approval is allowed, independent of certificate validity.

**Limit-blocked** — An Enrollment Request that passed every automatic-approval criterion except quota and stays pending with the reason "auto-approve passed but was not approved due to limit."

**Pending diagnostics** — The per-policy and aggregate reasons an Enrollment Request remains pending instead of being automatically approved.

**Admission ledger** — The durable, immutable record of committed automatic admissions used for idempotency and audit.
