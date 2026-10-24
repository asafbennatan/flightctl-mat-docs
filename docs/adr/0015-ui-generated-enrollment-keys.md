---
status: proposed
---

# Generate enrollment keys in the UI with CSR-only issuance

The enrollment credential UI generates an ECDSA P-256 key pair and PKCS#10
CSR in the browser. It submits only the CSR through the existing CSR API and
offers the private key to the operator for device provisioning. The server
never receives, stores, logs, provisions, or exports the private key, and the
browser does not persist it beyond the issuance flow.

Server-side key provisioning was rejected because it would make the Flight
Control control plane a long-term secret custodian. Requiring only an external
command-generated CSR was rejected as unnecessary operator friction now that
the UI is expected to support guided issuance. The tradeoff is that the browser
and the operator's download path join the trusted key-custody surface; the UI
must keep the key out of logs and application storage, and the operator must
protect the downloaded file.
