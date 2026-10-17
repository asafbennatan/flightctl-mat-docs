---
status: proposed
---

# Reuse the enrollment CSR as the credential identity

EDM-4868 does not introduce an EnrollmentCertificate resource.
The tenant-local `metadata.name` of the existing enrollment-signer
CertificateSigningRequest is the enrollment-credential identity.
The design extends that CSR's status with issuance time and a revocation
subresource instead of duplicating CSR inventory, issuance, and signer flow
in a new resource.

A dedicated EnrollmentCertificate resource would duplicate CSR inventory and
issuance while requiring migration of existing credentials.
A fingerprint or UUID identity would add a second identifier beside the
existing tenant-local primary key.
The issuer attests the exact CSR name in its signed enrollment certificate.
Enrollment Request creation reads that identity from the already authenticated
certificate/context to set the optional `status.enrollmentCertificateName`
reference, its only origin signal, without an identity-discovery or row-existence
lookup.
Device-supplied request-body fields are not trusted replacements.

Only when that signed identity is absent, attempt to recover it from the
issuing enrollment CSR within the authenticated tenant/organization. Decode its
retained issued certificate and match the exact presented leaf; a matching
common name or the ER's device-management CSR is not sufficient proof.
A unique actual issuing-CSR match supplies the same reference without
certificate reissuance. Missing identity must not be invented.

If reliable identity cannot be established, create the Enrollment Request with
the reference absent, as on pre-feature requests without saved origin.
There is no separate ER-origin classification or automatic backfill of stored
requests that lack the presented leaf.
Consumers requiring the CSR can filter out requests without the reference, then
resolve the referred CSR's authoritative state. Reference presence is only a
readiness prefilter: it does not prove the target still exists, is unrevoked,
has known issuance time, or meets other policy eligibility requirements.
A deleted or dangling target is unavailable when the consumer resolves it.
Missing metadata alone neither rejects an otherwise valid certificate nor
prevents Enrollment Request creation; ordinary certificate/mTLS authentication,
existing revocation checks, and Enrollment Request persistence are unchanged.
Operational errors are not identity proof; existing error handling is unchanged.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
Historical admissions whose issuing CSR identity cannot be reconstructed
remain explicitly `LegacyUnknown` rather than being linked through a
management certificate.
