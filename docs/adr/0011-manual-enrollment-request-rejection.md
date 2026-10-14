---
status: proposed
---

# Manual Enrollment Request rejection with explicit administrator override

Rejection applies only to pending Enrollment Requests and affects neither their
enrollment certificate nor other requests or enrolled devices. It is distinct
from enrollment-certificate revocation (ADR 0004) and from device eviction.

Manual decisions carry service-generated “Manually rejected” or “Manually
approved” reasons, the authenticated actor, and server time. Users and API
callers do not supply these values; rejection after certificate revocation
retains its separate reason. This makes decisions attributable without adding
a caller-authored reason input.

A manually rejected request can later be explicitly approved by an
administrator, subject to credential validity and revocation checks. Agent
updates, policy changes, and automatic approval cannot clear rejection. A
terminal rejection was rejected because an administrator needs to correct a
mistake; automatic reopening was rejected because it would override the human
decision.

For concurrent approval and rejection, the first committed decision wins and
the competitor receives a conflict. A committed rejection prevents stale
automatic approval, while a committed approval makes rejection invalid because
the request is no longer pending. Explicit later manual override is a new
decision, not successful completion of a stale competing operation.

Rejection survives agent restarts, repeated submissions, and updates to the
existing request. Deletion of a rejected request is refused: otherwise deletion
and recreation could bypass the human decision through automatic approval.
Recovery requires explicit administrator approval of the existing rejected
request.

A device in the field must discover later administrator approval and complete
enrollment without an operator restarting it. It continues periodic status
checks within the enrollment flow using the existing configurable backoff
settings plus jitter, rather than exiting and resubmitting on rejection.
Polling or process restarts never clear the rejection. Detecting explicit
administrator approval resumes enrollment automatically.

Manual rejection and explicit approval of a rejected request use the existing
enrollment-approval permission. No separate rejection or override permission
is introduced. Repeating the same decision returns the existing result without
changing its original actor or timestamp; concurrent opposite decisions still
follow the first-committed-decision rule.

Explicit approval changes the current outcome without erasing the earlier
manual rejection. Users can inspect the original rejection reason, actor, and
time alongside the later approval and its own attribution. Retrying a decision
does not rewrite this history.
