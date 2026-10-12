# 10: Include volumes and parent identities with lifecycle-safe collection

**What to build:** Applications with image-backed volumes and reported parent
OCI images or artifacts receive lastDelta only when the full reported image set
matches recorded outcomes from the same application lifetime.

**Status:** implemented

**Blocked by:** 09: Match application workload outcomes to one reported snapshot.

- [x] Gather workload, image-backed volume, and applicable parent observations
  into an owned application snapshot with explicit completeness.
- [x] Preserve artifact manifest identities and their existing full-artifact
  behavior; do not reinterpret them as executable-image platform manifests.
- [x] Record and match outcomes for required reported parents and volume images
  using their correct storage ownership and OCI type.
- [x] Validate application lifetime after separately gathered inputs; ordinary
  desired updates retain old matching results, while removal clears history.
- [x] Recreated application names reject obsolete observations/completions;
  missing observations, including unobservable expected workloads, suppress
  the complete aggregate rather than mixing different lifetimes.
- [x] Existing Store, application status, and volume/parent collection tests
  exercise updates during collection, restart, removal/recreation, and mixed
  workload/volume results without adding new mock-only interfaces.

**Validation:** `go test -race ./internal/agent/device/applications/... ./internal/agent/device/deltastatus ./internal/agent/device/dependency ./internal/agent/client -count=1`, `make lint`, `make -B lint-docs`, and `make -B spellcheck-docs` pass. A regression test changes an artifact-volume binding during inspection without changing `CreatedAt` and verifies that the incomplete snapshot withholds `lastDelta`. The Podman volume ownership and Quadlet recreation evidence is recorded in `podman-volume-identity-notes.md` alongside the runtime probe.
