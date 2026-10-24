---
status: proposed
---

# Allow manual override of a Device's revoked-credential flag

An administrator can dismiss the revoked-credential flag on one Device with an
immutable actor, time, and audit reason. The active revoked filter excludes
that Device, an audit selector includes it, and the flagging worker treats the
override as terminal, so an override committed during asynchronous flagging is
safe.

The override never un-revokes the enrollment credential, re-enables enrollment
with it, restores pending Enrollment Request approval, affects another Device,
or changes management renewal. Un-revocation was rejected because the
security-officer revocation decision must remain authoritative; a permanent,
unoverridable flag was rejected because operators need an auditable way to
dismiss false positives after review. There is no un-override operation.
