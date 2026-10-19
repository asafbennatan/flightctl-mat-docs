---
status: proposed
---

# Initial delta-generation failures fail open

The initial delta-generation existence check has three outcomes. A matching
delta artifact is reused. No matching artifact causes Flight Control to
generate one. Any check error is inconclusive and marks the generation failed
for the current prepare, which emits terminal progress and resumes the normal
rollout.

This policy applies to every initial existence-check error, including access
denial, timeouts, registry failures, and network failures. An inconclusive
check must not be treated as a missing delta. It also must not leave the
generation pending when the current prepare has no same-prepare retry
mechanism.

A later prepare that requires the same image pair uses the existing
failed-to-pending path to retry generation. A full image update remains the
safe fallback for the current rollout.

This decision is separate from periodic validation of successful generation
records. Periodic validation keeps successful records unchanged after
transient timeouts and registry failures so a later check can retry them.
