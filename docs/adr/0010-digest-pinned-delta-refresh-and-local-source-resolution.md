---
status: proposed
---

# Digest-pinned delta refresh and local source resolution

After an application image delta reconstructs a target, refresh the owning image store with a reference pinned to the selected target platform-manifest digest rather than re-resolving the original mutable tag. The runtime therefore records the canonical registry identity while reusing the reconstructed blobs. Verify the selected digest against the exact raw manifest bytes, using the digest algorithm already pinned by the reference when one is present.

Delta sources must be available in the store that will reconstruct the target. Resolve containerd sources from local runtime content before falling back to remote registry inspection, and continue local checks after the remote-inspection budget expires. This avoids unnecessary full pulls and prevents a remote-only source from being treated as locally usable.
