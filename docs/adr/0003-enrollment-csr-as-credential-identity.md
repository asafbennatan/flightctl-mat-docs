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
Names supplied by the device are never trusted: an authenticated enrollment
leaf is resolved to its actual issuing CSR and validated against the issued
certificate bytes, failing closed when resolution is absent or ambiguous.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
Historical admissions whose issuing CSR identity cannot be reconstructed
remain explicitly `LegacyUnknown` rather than being linked through a
management certificate.
