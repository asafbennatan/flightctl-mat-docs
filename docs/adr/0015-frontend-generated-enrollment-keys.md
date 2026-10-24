---
status: proposed
---

# Generate enrollment keys and CSRs in the frontend

The enrollment credential UI generates an ECDSA P-256 key pair and a PKCS#10
CSR in the browser. The CSR API remains unchanged: the UI submits only the CSR
through the existing CertificateSigningRequest endpoint, and the server never
receives, stores, logs, provisions, or exports the private key. The browser
does not persist the key beyond the issuance flow, and the operator receives
it only for device provisioning.

Server-side key provisioning was rejected because it would make the Flight
Control control plane a long-term secret custodian. Operator-local command-only
issuance was rejected as unnecessary friction now that the UI is expected to
support guided issuance. The tradeoff is that the browser and the operator's
download path join the trusted key-custody surface; the UI must keep the key
out of logs and application storage, and the operator must protect the
downloaded file.
