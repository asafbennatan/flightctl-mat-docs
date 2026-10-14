# Flight Control Glossary

## Image references and digests

**Image reference** — A registry name that selects an image, optionally through a tag or digest.

**Digest-pinned image reference** — An image reference that names a registry object by digest instead of a mutable tag.

**Image index digest** — The digest of an image index that selects platform-specific manifests.

**Platform manifest digest** — The digest of an image manifest for one platform. For a multi-platform image, it can differ from the image index digest.

**Desired target digest** — The registry digest associated with the image selected as the desired update target. For a multi-platform image, it can identify the index rather than a platform manifest.

**OCI referrer subject digest** — The digest of the image object a referrer is associated with, such as an image index or platform manifest. Referrer lookup is keyed by this digest. It identifies the subject object, not the referrer artifact or a manifest reconstructed by applying a delta.

**Source image digest** — The digest of the base image from which an OCI delta reconstructs a target image.

**Reconstructed manifest digest** — The digest of the image manifest produced by applying a delta. It can differ from the canonical manifest digest for the desired target image.

**Observed image digest** — A verified registry digest identifying the image currently held or run by its owning subsystem, independently of the delta outcome. For a multi-platform image, it is the verified index digest when that identity is available, otherwise the observed platform manifest digest.

**Delta artifact digest** — The digest identifying the OCI artifact that carries a delta. It identifies the delta artifact, not the source or target image.

**Runtime image ID** — An identifier assigned by an image runtime. It may be opaque and is not necessarily a registry image digest.

## Image deltas

**OCI image delta** — An OCI artifact containing the changes needed to reconstruct a target image from a source image.

**Delta hint** — A reference supplied with an update to identify a specific delta artifact.

**Delta discovery** — Finding a delta related to a desired image when an update does not identify one directly.

**Delta apply outcome** — The agent's result for using a delta during an update. It describes the update attempt, separately from image identity.

**Last delta result** — The delta apply outcome associated with the observed image identities currently reported for an OS or application. An application's result describes its reported image set, including workload images and image-backed volumes.

**NotRequired** — The existing target image satisfies the agent's image pull rules, so neither a delta nor a full image fetch is needed. This outcome does not imply a fresh registry digest verification.

**NotUsed** — Delta application was skipped without a delta-apply failure; a full image fetch may still be needed.

**Applied** — All delta work for the target succeeded.

**Fallback** — A hinted or selected delta could not be used or applied, so the agent attempted a full image pull. The result carries a reason.

**Partial** — An application update applied a delta to at least one image target and used no delta or fell back for another. Targets reported as `NotRequired` do not make the result partial.

**Fallback reason** — The explanation associated with a `Fallback` result. An application with multiple fallback failures reports one deterministic representative reason.

## Authentication

**AuthProvider** — A Flight Control resource that describes an identity provider and its authentication configuration.

## Enrollment auto-approval

**Enrollment certificate** — A bootstrap certificate issued to a device so it can submit an Enrollment Request; it authorizes enrollment, not ongoing management.

**Issuing CSR** — The existing CertificateSigningRequest whose tenant-local name identifies an enrollment certificate; it is the credential identity.

**Issuance** — The committed result of signing an enrollment certificate, together with its server-owned issuance time.

**Exact leaf identity** — The unique identity of one presented enrollment-certificate leaf; it resolves to exactly one issuing CSR and is independent of names and serial numbers.

**Issuing-CSR binding** — The relationship stored on an Enrollment Request between that request and the issuing CSR of the enrollment certificate that authenticated its creation.

**Enrollment Request (ER)** — A device-submitted request for a management certificate whose approval creates the same-named Device.

**Reported identifiers** — Device-supplied facts on an Enrollment Request, such as serial and product identifiers; they are policy-matching inputs, not trust evidence.

**EnrollmentApprovalPolicy** — The administrator resource defining automatic approval rules for exactly one enrollment certificate.

**Match expression** — A restricted boolean policy expression over reported identifiers; it never evaluates certificate identity or TPM status.

**Policy set** — The enabled EnrollmentApprovalPolicies that share one enrollment certificate and are evaluated together under exact-one-match.

**Automatic approval** — Server-side approval of an Enrollment Request when the credential, exactly one matching enabled policy, all required gates, and quota checks pass.

**Manual approval** — The existing human approval path; requests that match no policy or are blocked by a limit remain pending for it.

**Policy provenance** — The policy name and version recorded when a policy causes an automatic admission.

**Exact-one-match** — The runtime requirement that exactly one enabled policy for the credential passes; zero or multiple matches leave the request pending with a reason.

**Provably disjoint** — The requirement that enabled policies sharing a certificate have match expressions whose overlap is statically provable to be empty.

**Label seal** — The one-time label assignment at automatic approval: static administrator labels plus explicitly allowed incoming keys, with static values winning.

**Static device labels** — Administrator-defined labels a policy always applies at automatic approval.

**Allowed incoming labels** — Exact Enrollment Request label keys an administrator explicitly permits through the label seal; unlisted keys are dropped.

**Approval limit** — An optional per-policy lifetime maximum of automatic approvals; omitted means unlimited and zero blocks automatic approval.

**Enrollment count** — The server-owned number of committed automatic approvals under a policy; it always increments and never resets.

**Auto-approval window** — An optional per-policy number of days after certificate issuance during which automatic approval is allowed, independent of certificate validity.

**Limit-blocked** — An Enrollment Request that passed every automatic-approval criterion except quota and stays pending with the reason "auto-approve passed but was not approved due to limit."

**Pending diagnostics** — The per-policy and aggregate reasons an Enrollment Request remains pending instead of being automatically approved.

**Enrollment revocation** — Security-officer revocation of an enrollment certificate, enforced at mTLS verification; it blocks new enrollment and rejects pending requests.

**Flagging** — Marking automatically onboarded devices associated with a revoked enrollment certificate so operators can identify them.

**Eviction** — Removal of an enrolled device's management access; enrollment revocation never evicts.

**TPM challenge** — An out-of-band proof that the requester controls the TPM key attested by an Enrollment Request's CSR; success is recorded as TPM verified.

**TPM verified** — A server-verified boolean reflecting completed TPM enrollment evidence; it never upgrades the assurance of agent-reported identifiers.

**Trust gate** — A server-verified prerequisite outside the match expression, such as TPM verified or an unrevoked enrollment certificate.

**LegacyUnknown** — The explicit state for historical admissions whose issuing CSR identity cannot be trustworthily reconstructed.

**Admission** — The committed result of Enrollment Request approval: the same-named Device becomes enrolled and receives its management certificate.

**Admission ledger** — The durable, immutable record of committed automatic admissions used for idempotency and audit.
