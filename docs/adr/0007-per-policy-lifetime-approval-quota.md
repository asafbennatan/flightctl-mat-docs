---
status: proposed
---

# Per-policy lifetime approval quota without rate limiting

Each EnrollmentApprovalPolicy carries an optional `approvalLimit` — omitted or
null means unlimited, zero blocks automatic approval — and an
always-incrementing server-owned `status.enrollmentCount`.
The count is committed in the same primary-database transaction as Enrollment
Request approval, Device creation, and the admission ledger, so concurrent
attempts and retries cannot exceed a finite cap or double count.
No per-minute or burst rate limiting is introduced; usage protection is a
lifetime quota only.

A certificate-shared quota was rejected because multiple disjoint policies
under one credential need independent counts.
Rate and burst limits were rejected as out of scope and hard to make fair
across distributed admission.
A stored remaining-count field was rejected as redundant because availability
is computed from the limit and count.
An otherwise eligible quota-blocked request stays pending with the exact
reason "auto-approve passed but was not approved due to limit"; it is never
rejected or silently redirected to manual approval.
