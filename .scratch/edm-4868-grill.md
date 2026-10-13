# EDM-4868 grill-with-docs record

Auto-filled from the EDM-4868 PRD and technical design (revision 7) in
`flightctl/design-docs` PRs #59 and #61.
Answers marked **[settled]** are decisions already recorded in those documents;
answers marked **[open]** still require stakeholder decisions.
This record exists so outside stakeholders can see the questions the design
already answers and the questions that remain.

## Round 1 — Trust foundation

❓ **Q1** - **Primary trust signal**: What admits a device without individual human approval?

➡️ **[settled]** A valid enrollment credential issued by an existing enrollment-signer CSR is the primary trust signal. Policy matching, optional TPM verification, quota, and the issuance window are additional gates on top of it — never replacements for it. (PRD §1; Design §1)

---

❓ **Q2** - **Credential identity resource**: Do we introduce an EnrollmentCertificate resource?

➡️ **[settled]** No. The existing enrollment-signer CSR's tenant-local name is the credential identity; CSR status gains issuance time and a revocation subresource. EnrollmentApprovalPolicy is the only new top-level resource. (Design §1, §2.1, §4; ADR 0003)

---

❓ **Q3** - **Default state**: Is auto-approval enabled by default?

➡️ **[settled]** No. Auto-approval is disabled by default and administrators must explicitly opt in per policy. (PRD FR-1)

---

❓ **Q4** - **Self-declared trust**: Can a device satisfy trust requirements by declaring them itself?

➡️ **[settled]** No. `tpm.verified` is a server-verified boolean from completed TPM enrollment evidence; reported serial, productSerial, and productUuid remain agent-reported, non-attested claims even when TPM verification succeeds. Successful TPM verification never upgrades identifier assurance. (PRD FR-4, FR-5; Design §5.1, §10)

---

## Round 2 — Policy matching

❓ **Q5** - **Matching fields**: Which fields can policies match?

➡️ **[settled]** CEL runs only on the identifier fields the ER already reports under `spec.deviceStatus.systemInfo` — productSerial, productUuid, and a configured generic `serial` in `customInfo`. The certificate is the separate `spec.certificateName` boundary and the TPM requirement is a separate policy field alongside it, so neither is a CEL input. Arbitrary device-reported key/value matching is excluded. (PRD FR-2; Design §5.1)

---

❓ **Q6** - **Policies per certificate**: One policy per certificate, or many?

➡️ **[settled]** Multiple policies may select the same certificate, but enabled policies must be provably disjoint, and runtime admission requires exactly one matching enabled policy. Zero or multiple matches leave the request pending with a reason; overlapping or unprovable enabled configurations are refused at authoring time. (PRD FR-2, AC-2; Design §5.2; ADR 0005)

---

❓ **Q7** - **Expression language**: Why CEL, and why restricted?

➡️ **[settled]** Matching is boolean CEL over a restricted typed view of the ER's reported device status, with no generic maps, clocks, network calls, or callbacks, and no `reported.*` alias namespace — expressions use the ER's existing paths. The bounded subset (boolean operators, typed equality against literals, finite membership, `startsWith` on serial/productSerial, presence guards) makes overlap decidable so disjointness can be proven, not promised by examples. (Design §5)

---

❓ **Q8** - **Pending requests under policy change**: What happens to pending requests when policies change?

➡️ **[settled]** Pending requests that stop matching remain pending for manual approval; they are never auto-rejected by policy changes. Already approved requests remain unchanged and are not revoked by policy changes. Certificate revocation is the only case in this workflow that rejects pending requests. (PRD FR-3, AC-3)

---

## Round 3 — Labels

❓ **Q9** - **Fleet self-selection**: Can a device choose its fleet through reported labels?

➡️ **[settled]** No. At automatic approval the Device receives static administrator labels merged with explicitly allowlisted incoming ER keys; static values win collisions and unlisted keys are dropped. The label seal is one-time — afterward label-sync and administrative label edits work normally. (PRD FR-6, AC-6; Design §6; ADR 0006)

---

## Round 4 — Limits and windows

❓ **Q10** - **Bounding credential abuse**: How do we limit what a shared credential can admit?

➡️ **[settled]** Each policy has an optional lifetime `approvalLimit` (omitted means unlimited, zero blocks) and a server-owned `enrollmentCount` that always increments on committed automatic approval and never resets. There is no per-minute or burst rate limiting. A request that passes all criteria except quota stays pending with the exact reason "auto-approve passed but was not approved due to limit." (PRD FR-3, FR-9, NFR-3, AC-8; Design §7; ADR 0007)

---

❓ **Q11** - **Certificate lifetime**: Do we shorten enrollment-certificate lifetime to bound exposure?

➡️ **[settled]** No. The existing one-year default and explicit expiration settings are unchanged. Each policy may optionally set `autoApprovalWindowDays` measured from server-recorded CSR issuance time, so a credential can be valid for a year while auto-approving only during its first N days. Window expiry means manual fallback, never revocation. (PRD FR-10, AC-9; Design §8; ADR 0008)

---

## Round 5 — Revocation

❓ **Q12** - **Revocation semantics**: What does revoking an enrollment certificate do, and where is it enforced?

➡️ **[settled]** Revocation is enforced at mTLS verification via a `VerifyConnection` hook plus a primary-database barrier on every enrollment handshake, failing closed. It blocks new enrollment immediately, rejects associated pending ERs with a reason, and flags all automatically onboarded devices associated with the certificate within five minutes. It does not evict enrolled devices or stop management-certificate renewal. (PRD FR-11, NFR-2, AC-10; Design §9; ADR 0004)

---

## Round 6 — Interfaces, scale, and rollout

❓ **Q13** - **Interface parity**: Which operations must exist in UI, CLI, and API?

➡️ **[settled]** Five operations, in all three surfaces: manage policies, view approval/pending/rejection reasons, configure approval quota, revoke enrollment certificates, and identify policy/affected devices. Policy authoring also shows the selected certificate's expiry date and days remaining, separately from any auto-approval window end time. (PRD FR-12, FR-13, AC-11, AC-12; Design §11)

---

❓ **Q14** - **Scale proof**: How do we prove fleet-scale onboarding?

➡️ **[settled]** A fleet-scale demonstration automatically approves 5000 devices with no manual approvals and shows administrator-defined labels placing approved devices in the intended fleet. (PRD FR-15, AC-14; Design §14.3)

---

❓ **Q15** - **Rollback**: What is safe to roll back?

➡️ **[settled]** Disabling policies is safe and leaves pending/approved ERs and enrolled devices unchanged. Rolling back to code that ignores revocation is unsafe; enrollment must stop or compatible code must be restored. Counters and audit history must not be erased while credentials can be presented. (Design §15)

---

## Round 7 — Open questions for stakeholders

These are the design's remaining review questions (Design §16). Each has a recommendation but no recorded decision.

❓ **Q16** - **Default window**: What auto-approval window should administrators recommend?

➡️ **[open]** Security + Product. Optional `autoApprovalWindowDays` in 1–106751 (for example 30), separate from unchanged certificate lifetime; no mandatory default.

---

❓ **Q17** - **Recommended limits**: What finite approval limits should administrators recommend?

➡️ **[open]** Security + Product. Omission is unlimited and counts always increment; examples are operational recommendations, not a default cap.

---

❓ **Q18** - **CEL subset sufficiency**: Is the documented provably-disjoint CEL subset sufficient for commissioning groups?

➡️ **[open]** Core + UX + Security. Use bounded prefix/set/boolean/presence clauses; reject unprovable overlaps and never weaken exact-one runtime safety.

---

❓ **Q19** - **Resource bounds**: Are 4 KiB / 32 clauses / 32 enabled policies appropriate?

➡️ **[open]** Core + SRE. Benchmark compilation, overlap, and evaluation before signoff while preserving deterministic bounds.

---

❓ **Q20** - **Generic serial source**: Which existing key supplies generic serial?

➡️ **[open]** Agent + UX. productSerial/productUuid already exist; use configured `customInfo["serial"]` for generic serial with documented missing semantics, not a new report type.

---

❓ **Q21** - **Signing latency**: Is local signing within two seconds viable?

➡️ **[open]** Core + SRE. Measure; any alternate finalization must preserve locked policy/quota/revocation checks before publication.

---

❓ **Q22** - **Flag capacity**: What capacity guarantees persistent flags within 300 seconds?

➡️ **[open]** SRE + QE. Reserved priority workers and indexed ER/Device join; prove crash recovery at supported maximum.

---

❓ **Q23** - **Tombstone retention**: How long must CSR/ER/policy-snapshot tombstones be retained?

➡️ **[open]** Security + Docs + Core. Prevent name reuse and quota reset and retain the paper trail without storing keys or new Device relationships.

---

❓ **Q24** - **Signoff**: Have the PRD amendments and prerequisite security approval been accepted?

➡️ **[open]** Product + Security. Obtain written acknowledgement; the draft revision is not proof of either.
