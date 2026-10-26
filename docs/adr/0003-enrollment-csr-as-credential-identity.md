---
status: proposed
---

# Reuse the enrollment CSR as the credential identity

EDM-4868 does not introduce an EnrollmentCertificate resource.
The tenant-local `metadata.name` of the existing enrollment-signer
CertificateSigningRequest is the enrollment-credential identity.
The design extends that CSR's status with issuance time and a revocation
operation whose committed result is exposed in the CSR's public status,
instead of duplicating CSR inventory, issuance, and signer flow in a new
resource.

A dedicated EnrollmentCertificate resource would duplicate CSR inventory and
issuance while requiring migration of existing credentials.
A fingerprint or UUID identity would add a second identifier beside the
existing tenant-local primary key.
Enrollment authentication resolves the exact presented leaf to its issuing
enrollment CSR by matching the leaf DER against the private certificate-digest
index within the authenticated tenant/organization. Exactly one issuance
record must match; otherwise enrollment authentication fails closed and no
Enrollment Request is created. The resolved CSR name is carried in the
authenticated enrollment identity, and Enrollment Request creation persists it
as the optional `status.enrollmentCertificateName` reference.
Device-supplied request-body fields are not trusted replacements.

A matching common name, serial number, or the ER's device-management CSR is not
sufficient identity proof. The digest index covers credentials issued before
and after this design, so every enrollment certificate uses the same resolution
flow.

Existing Enrollment Requests without a stored reference retain that absence, as
on pre-feature requests without saved origin. There is no separate ER-origin
classification or automatic backfill of stored requests that lack the presented
leaf.
Consumers requiring the CSR can filter out requests without the reference, then
resolve the referred CSR's authoritative state. Reference presence is only a
readiness prefilter: it does not prove the target still exists, is unrevoked,
has known issuance time, or meets other policy eligibility requirements.
A deleted or dangling target is unavailable when the consumer resolves it.
Issuance metadata is policy input rather than authentication identity: a CSR
with certificate bytes but no `issuedAt` still authenticates enrollment, while
policy evaluation that requires an issuance window treats the missing time as
not satisfying that window. Operational errors are not identity proof;
authentication and request failures use the existing error handling.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
Historical admissions without a stored issuing-CSR reference retain that
absence, not a separate origin classification. Unknown credential provenance
is not reconstructed from a management certificate or later polling.
