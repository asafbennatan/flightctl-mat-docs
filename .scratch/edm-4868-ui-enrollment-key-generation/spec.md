Status: ready-for-agent

# EDM-4868 — UI-generated enrollment keys and CSRs

## Problem Statement

Fleet administrators need a guided way to create enrollment credentials without running a separate local command or copying files between tools. The existing CSR issuance API is already sufficient, but the operator experience does not yet generate the key and CSR in the UI or make the resulting private key available for device provisioning.

## Solution

The enrollment credential UI generates an ECDSA P-256 private key and PKCS#10 CSR in the browser. It submits only the CSR through the existing CSR API, keeps the private key out of Flight Control’s control plane, and offers the key to the operator for device provisioning. The CSR API remains unchanged.

## User Stories

1. As a fleet administrator, I want the enrollment UI to generate a private key and CSR for me, so that I do not need to run a separate local command.
2. As a fleet administrator, I want the UI to submit only the CSR to the existing CSR API, so that the server contract remains unchanged.
3. As a fleet administrator, I want the private key to remain in the browser during issuance, so that Flight Control never becomes its custodian.
4. As a fleet administrator, I want to download the private key after CSR submission, so that I can provision devices with the enrollment credential.
5. As a fleet administrator, I want the UI to avoid persisting the private key after issuance, so that repeated sessions do not accumulate secrets.
6. As a security officer, I want the server to never receive, store, log, or export the private key, so that the control plane cannot leak it.
7. As a security officer, I want the UI to keep the key out of application storage and logs, so that browser-side handling does not create an unintended secret store.
8. As a fleet administrator, I want the UI to show the CSR name and certificate expiry after issuance, so that I can manage the credential without another tool.
9. As a fleet administrator, I want the existing CSR API behavior preserved, so that automation and CLI workflows continue to work unchanged.
10. As a fleet administrator, I want the UI to warn me to protect the downloaded private key, so that I understand my responsibility for credential custody.

## Implementation Decisions

- The enrollment UI generates an ECDSA P-256 key pair and a PKCS#10 CSR locally.
- The CSR API remains unchanged; the UI submits only the CSR.
- The server never receives, stores, logs, provisions, or exports the private key.
- The browser does not persist the private key beyond the issuance flow.
- The operator may download the private key for device provisioning.
- The UI must keep the key out of application storage and logs.
- This decision is recorded in ADR 0015.

## Testing Decisions

- Good tests assert externally visible behavior at the CSR API and UI issuance boundary, not private implementation details.
- Verify that the UI submits a valid CSR and that the CSR API accepts it unchanged.
- Verify that no private-key material appears in network requests, server logs, application storage, or API responses.
- Verify that the operator can download the private key and that the UI does not retain it after issuance.
- Prior art is the existing CSR issuance and UI workflow tests.

## Out of Scope

- Server-side key generation or key provisioning.
- Changes to the CSR API contract.
- A new credential resource or identity type.
- Key escrow, recovery, or rotation.
- Management-certificate issuance or renewal.

## Further Notes

- The operator remains responsible for protecting the downloaded private key.
- The browser and the operator’s download path join the trusted key-custody surface.
