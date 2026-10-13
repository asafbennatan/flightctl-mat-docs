---
status: proposed
---

# Restricted CEL policies with exact-one-match enforcement

EnrollmentApprovalPolicy matching is boolean CEL over a closed, typed input
set — reported `serial`, `productSerial`, and `productUuid`, certificate name
and organization, and server-verified TPM status — restricted to a bounded
subset in which policy overlap is decidable.
Multiple enabled policies may share a certificate only when provably disjoint,
and admission requires exactly one passing policy.
Zero matches or unexpected multiple matches leave the Enrollment Request
pending with a reason; no implicit priority resolves a conflict.

Arbitrary key/value matching was rejected because device-reported keys are
spoofable and arbitrary expression overlap cannot be soundly decided by
sampling.
Implicit policy priority was rejected because it silently masks configuration
conflicts instead of surfacing them.
A single policy per certificate was rejected because disjoint commissioning
groups legitimately need separate static labels under one credential.
Candidate evaluation errors mark that candidate nonpassing without vetoing
another passing policy.
