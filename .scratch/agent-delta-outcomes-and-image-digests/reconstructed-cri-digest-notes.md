# Live CRI reconstruction exploration

Evidence: `/tmp/flightctl-cri-reconstruction-evidence.json`.
Setup/run scripts: `/tmp/flightctl-cri-reconstruction-launch.py`, `/tmp/flightctl-cri-create-delta.sh`, `/tmp/flightctl-cri-reconstruction-run.py`.
No repository changes or ticket closure were performed.

## Findings

MicroShift 4.19 / CRI-O 1.32.8 / cri-tools 1.32.0 ran inside a unique privileged MINC container, with an isolated named storage volume and guest-loopback API port. CRI-O reported graphroot `/var/lib/containers/storage`, runroot `/run/containers/storage`, and isolated `/host-container` additional storage. The existing VM's `/usr/bin/oci-delta` binary copied into `/tmp` inside MINC ran using the container's installed libraries; no VM package/configuration changes were needed.

An actual Alpine 3.21 → 3.22 OCI delta was created with one worker from registry OCI layouts (~1 MiB archive). The source was pulled through CRI into the owning store. `oci-delta import --container-storage /var/lib/containers/storage --tag docker.io/library/alpine:3.22` reconstructed content in that same CRI store. CRI inspection saw the reconstructed image before a canonical target pull.

A Never-pull pod ran the reconstructed image. Its Kubernetes imageID and CRI container imageRef both reported reconstructed manifest `sha256:1ea478bc4da50dfb0c466db6d757ba28980b0a029139091c3bf525184b699022`, independently hashed through local containers/storage. This differs from canonical linux/amd64 target manifest `sha256:3e9b4b680bfc9fb5269227cffbd6d42be39fbf7c0b908123913864aa4447e764`.

After `crictl pull` of the canonical index-pinned Alpine 3.22 publication, a second Never-pull pod reported the canonical platform manifest in both Kubernetes imageID and CRI imageRef. The old pod remained Running/Ready and retained its reconstructed manifest identity. Both running pods reported Alpine 3.22.6 and identical busybox hashes; this checks selected content rather than a complete filesystem equivalence proof.

Raw registry requests by explicit index and platform digests verified their SHA256 hashes and linux/amd64 child membership. An initial check incorrectly compared the raw tagged index to the platform digest; that verification was corrected using explicit registry-object requests after cleanup. Captured runtime measurements were unchanged.

The isolated container, volume, newly pulled MINC image, and VM delta/layout temp directory were removed. The existing flightctl-agent remained active. No bootc staging/reboot or production file edits occurred.

## Limits

The import used the tagged target, while canonical refresh requested its index-pinned publication. This proves actual reconstructed-content observation and canonical index/platform observation, but does not alone establish the production import/refresh sequence for every exact reference form. Digest-pinned import itself, same-tag refresh, containerd, repository MicroShift 4.21, and bootc reconstruction remain untested here.

## Isolated bootc VM feasibility

An offline base exists at `/home/abennata/dev/flightctl/bin/output/qcow2/disk.qcow2` (1.4 GiB allocated, 15 GiB virtual, no backing chain). `/home/abennata/dev/flightctl/bin/flightctl-dev-vm start` accepts `--base-disk`, `--name`, `--ssh-port`, `--work-dir`, and `--mem`, and creates an overlay. User-session libvirt is available. The host has about 124 GiB filesystem space and 16 GiB available RAM; a separate 2 GiB VM is feasible.

No clone was created. Use the offline base and unique overlay/state directory, VM name and SSH port; do not clone the active VM's writable disk or change/reboot the active VM. The base's enrollment/configuration has not been inspected, so its agent lifecycle needs to be assessed before using a clone for destructive OS staging experiments.
