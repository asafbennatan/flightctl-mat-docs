---
status: accepted
---

# No delta generation on fleet join

When a device joins a fleet — its owner becomes a fleet through selector
matching — Flight Control does not generate new image deltas for it. The
device render looks up an existing successful delta for the device's
`(repository, source digest, target digest)` pair and attaches it as a hint
when one matches; otherwise the device falls back to a full image fetch.
This applies equally to OS image deltas and application image deltas.

Delta generation stays bound to fleet template changes: the fleet's
`PrepareDeltas` event lists the devices owned by the fleet at that moment
and computes their candidate digest pairs. A device that joins afterward
was not in that snapshot. The standalone device prepare path excludes
fleet-owned devices, so nothing re-drives generation for the join itself.

This is accepted for now. Fleet join is a bounded, one-time cost, and the
prepare machinery stays keyed to template-version identity rather than
membership churn. A later revisit can start from the options below.

## Considered Options

- **Device-scoped prepare on spec change** — mirror the standalone path by
  emitting a device `PrepareDeltas` and holding render when a fleet-owned
  device's spec changes. Deferred: it fires on every fleet rollout spec
  write (not only joins), and the device-event prepare path would need to
  learn the owning fleet's delta-generation opt-out, which it does not
  check today.
- **Fleet re-prepare on membership change** — re-emit the fleet
  `PrepareDeltas` when a device joins. Deferred: membership churn would
  re-drive a fleet-wide, template-version-keyed workflow for a single
  device's benefit.
- **Render-time generation on hint miss** — deferred: it couples the
  render read path with generation side effects and still requires a
  re-render to deliver the resulting hint.
