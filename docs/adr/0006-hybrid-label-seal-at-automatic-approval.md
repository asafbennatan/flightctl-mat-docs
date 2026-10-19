---
status: proposed
---

# Hybrid label seal at automatic approval

At automatic approval the Device receives a fresh label map built from static
administrator labels plus explicitly allowlisted ER-reported labels, with
static values winning collisions and unlisted ER-reported labels dropped.
The result is recorded in ER approval, committed with `replaceLabels=true`,
and copied to `Device.metadata.labels`.
Pure static labels were rejected because administrators lose device-supplied
metadata they are willing to authorize; unrestricted ER label merge was
rejected because a device could select its own fleet.

The seal's restriction applies only to ER-reported labels.
Label mapping is relevant only to onboarded devices: it derives labels from
device status and has no bearing on Enrollment Requests.

The seal is a one-time action at the moment of automatic approval, not a
permanent label lock.
Afterward the Device is a normal device: label-sync and administrative label
edits work under their existing rules, and enrollment hooks and retries must
preserve stored labels, including later authorized changes, rather than
reapplying the approval snapshot.
Direct agent status updates still never write Device metadata labels.
