# Actual bootc update and multi-platform identity

Versioned machine-readable evidence: `bootc-update-evidence.json` (schemaVersion 1). Verified 12 October 2026 with bootc 1.16.13 on an isolated 2 GiB amd64 VM cloned through a private qcow2 overlay. The agent was masked offline in both sysroot and OSTree deployment before first boot, and remained masked/inactive.

A real four-architecture CentOS Stream 9 image index was selected by immutable digest. Its raw index hash and linux/amd64 child manifest hash were independently fetched and verified. `bootc switch` staged the update, then an actual target boot completed. The index-pinned reference remained in desired and booted image references, but both staged and booted `imageDigest` were the selected platform manifest digest. The old image stayed booted while the new one was staged, then became rollback after reboot. No index/platform alias is needed in delta outcome history: record the verified staged digest and match it against the later booted digest.

The public target dropped the developer user's sudo configuration. After first target boot, only the clone was gracefully shut down, its private mutable etc received temporary sudo access offline, then it was restarted to obtain root-required bootc status. This did not change target immutable content. The original agent VM was never staged, rebooted, or reconfigured.

Cleanup removed only the private VM/domain and overlay, closed SSH port 2236, and removed its empty work directories. The original VM remains booted on its original v14 digest with active agent and no staged image. No external registry objects were published.

This validates ordinary multi-platform bootc staging and actual boot, not OCI-delta reconstructed OS import/staging. The initial clone image's registry was unavailable; no independent initial raw manifest verification is claimed. Ticket 12 remains open pending its dependencies and final validation.
