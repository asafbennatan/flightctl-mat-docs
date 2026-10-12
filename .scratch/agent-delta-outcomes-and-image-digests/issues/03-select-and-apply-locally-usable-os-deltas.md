# 03: Select and apply locally usable OS deltas

**What to build:** OS image updates use a hinted or discovered OCI image delta only when its source image is available in the bootc-managed image store. The agent applies and stages that delta through the existing OS flow, reports a consistent outcome, and recovers through the full target operation when delta use fails.

**Blocked by:** None (can start immediately).

Status: ready-for-agent

- [ ] A hinted delta's source image digest is read from the delta artifact metadata and checked for availability in the bootc-managed image store.
- [ ] A missing, invalid, or otherwise unusable hinted delta reports Fallback with a reason and proceeds through the full OS target path.
- [ ] Discovery considers related OCI delta referrers from the desired image's repository and retains only candidates whose declared source image is locally available.
- [ ] Discovery selects the candidate with the lowest total downloadable artifact size and breaks ties deterministically by candidate reference.
- [ ] An already-present desired OS target with the correct digest reports NotRequired; an update with no selected candidate reports NotUsed.
- [ ] Applied is reported only after reconstruction, bootc staging, and canonical desired-reference staging all succeed.
- [ ] Download, reconstruction, staging, or refresh failures report Fallback with a reason and attempt the full OS target operation.
- [ ] Reconciliation succeeds when full-target recovery succeeds and fails when the full-target operation fails.
- [ ] The OS outcome survives restart while the desired image target is unchanged, resets for a changed target, and is preserved for a hint-only change.
- [ ] OS manager behavior tests cover source validation, discovery ranking, outcomes, staging, recovery, and persistence.
