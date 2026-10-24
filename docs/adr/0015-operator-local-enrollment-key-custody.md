---
status: proposed
---

# Keep UI enrollment key generation operator-local

The enrollment credential UI accepts only a CSR generated outside Flight
Control. It displays a copyable command for creating the key and CSR on the
operator's workstation, but never generates, receives, stores, logs, or
downloads the private key. Browser-side WebCrypto generation and server-side
key provisioning were rejected because either would unnecessarily expand the
trusted computing surface. This preserves the existing CSR resource and
issuance flow while keeping the UI and control plane out of enrollment
private-key custody.
