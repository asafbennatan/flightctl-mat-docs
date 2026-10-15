---
status: proposed
---

# Digest-pinned delta refresh and local source resolution

After an application image delta reconstructs a target, refresh the owning image store with a reference pinned to the selected target platform-manifest digest rather than re-resolving the original mutable tag. The runtime therefore records the canonical registry identity while reusing the reconstructed blobs. Verify the selected digest against the exact raw manifest bytes, using the digest algorithm already pinned by the reference when one is present.

Delta sources must be available in the store that will reconstruct the target. Resolve containerd sources from local runtime content before falling back to remote registry inspection, and continue local checks after the remote-inspection budget expires. This avoids unnecessary full pulls and prevents a remote-only source from being treated as locally usable.

Artifact identity remains canonical at the client boundary: a digest-pinned artifact reference is `REPOSITORY@sha256:<hex>`, and the observed artifact digest is the full algorithm-qualified digest. Because Podman 5.x cannot address a tag-pulled local artifact through that canonical reference but can address it by the digest's encoded hexadecimal value, the agent translates canonical artifact digests to that runtime-local selector only inside the Podman client for inspection and extraction. The encoded selector is never exposed as an identity, and references that combine a tag and a digest are rejected rather than forwarded to the runtime.
