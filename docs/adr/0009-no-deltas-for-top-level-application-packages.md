---
status: proposed
---

# No deltas for top-level application packages

Top-level application packages are the manifest-like artifacts that define a Helm, Compose, or Quadlet application. They are fetched through their normal package paths; OCI image deltas apply only to that application's nested workload images and image-backed volume images. Every nested workload image remains independently eligible for delta generation and application, even though its parent package is not.

An already-present top-level package is a no-op: it reports `NotRequired`, even when an image-delta hint is present. Treating such a hint as `Fallback` would make a satisfied package look like a failed delta attempt and could change the application's aggregate outcome. A missing package still uses its normal package path; a supplied hint does not make the package itself an image-delta target.
