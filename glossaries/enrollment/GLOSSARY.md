# Enrollment

This context describes enrollment credentials, Enrollment Requests, TPM proof, revocation, and device admission.

## Language

### Credential lifecycle

**Enrollment certificate** — A bootstrap certificate issued to a device so it can submit an Enrollment Request; it authorizes enrollment, not ongoing management.

**Enrollment credential CSR** — The CertificateSigningRequest an administrator creates to request an enrollment certificate; its tenant-local name is the credential identity.
_Avoid_: Issuing CSR

**Enrollment credential CSR creation** — An administrator's creation of an enrollment credential CSR; it requests a certificate but does not issue one.

**Enrollment credential CSR approval** — Approval and signing of an enrollment credential CSR, which publishes certificate bytes to that CSR's status; enrollment credential CSRs are automatically approved.

**Enrollment certificate issuance** — The committed publication of an enrollment certificate and its server-owned issuance time to an enrollment credential CSR's status.

**Enrollment private key** — The private key whose public key appears in an enrollment credential CSR; its operator keeps it outside Flight Control when creating the CSR.

**Exact leaf identity** — The unique identity of one presented enrollment-certificate leaf; it resolves to exactly one enrollment credential CSR and is independent of names and serial numbers.

### Enrollment Request and admission

**Enrollment Request (ER)** — A device-submitted request for a management certificate whose approval creates the same-named Device.

**Management-certificate CSR** — The CSR inside an Enrollment Request that requests the device's ongoing management certificate; it is not the enrollment credential CSR.

**Enrollment Request submission** — A device's authenticated submission of an Enrollment Request through enrollment mTLS using its enrollment certificate.

**Credential CSR binding** — The optional reference from an Enrollment Request to the enrollment credential CSR whose certificate authenticated its creation.

**Enrollment Request approval** — Authorization of an Enrollment Request to create its same-named Device and management certificate; it may be manual or automatic.

**Manual approval** — The existing human approval path; requests that match no policy or are blocked by a limit remain pending for it.

**Enrollment Request rejection** — A decision that refuses a pending request for admission; it does not revoke the enrollment certificate, affect other requests, or evict an enrolled device.
_Avoid_: ER revocation

**Manual rejection override** — An administrator's explicit approval of a previously manually rejected Enrollment Request, while its enrollment credential remains valid and unrevoked. Automatic processing cannot perform this override.

**Admission** — The committed result of Enrollment Request approval: the same-named Device becomes enrolled and receives its management certificate.

**Device enrollment provenance** — The server-owned facts identifying the enrollment credential and, for automatic approval, the policy that admitted a Device.
_Avoid_: Device provenance object

### Enrollment trust and revocation

**TPM challenge** — An out-of-band proof that the requester controls the TPM key attested by an Enrollment Request's CSR; success is recorded as TPM verified.

**TPM verified** — A server-verified boolean reflecting completed TPM enrollment evidence; it never upgrades the assurance of agent-reported identifiers.

**Trust gate** — A server-verified prerequisite outside the match expression, such as TPM verified or an unrevoked enrollment certificate.

**Enrollment revocation** — Security-officer revocation of an enrollment certificate, enforced at mTLS verification; it blocks new enrollment and rejects pending requests.

**Flagging** — Marking automatically onboarded devices associated with a revoked enrollment certificate so operators can identify them.

**Revoked-credential flag** — The server-owned marker placed on a Device admitted by a revoked enrollment certificate; it identifies the Device for review without quarantining it.

**Manual flag override** — An administrator's auditable dismissal of one Device's revoked-credential flag; it never reverses enrollment revocation.
_Avoid_: Un-revocation

**Eviction** — Removal of an enrolled device's management access; enrollment revocation never evicts.
