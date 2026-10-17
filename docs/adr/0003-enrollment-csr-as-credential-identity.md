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
The issuer carries the exact CSR name and the enrollment-credential details
needed on the Enrollment Request in its signed enrollment certificate.
Enrollment Request creation reads those details from the already authenticated
certificate/context without an additional CSR identity or details lookup.
Device-supplied request-body fields are not trusted replacements.

Legacy certificates remain usable when those details are absent: create the
Enrollment Request without the missing details and explicitly mark it as legacy.
Legacy Enrollment Requests are ineligible for EnrollmentApprovalPolicy approval.
Do not invent missing details or discover them through a database fallback.
Missing metadata alone neither rejects an otherwise valid certificate nor
prevents Enrollment Request creation; ordinary certificate/mTLS authentication,
existing revocation checks, and Enrollment Request persistence are unchanged.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
Historical admissions whose issuing CSR identity cannot be reconstructed
remain explicitly `LegacyUnknown` rather than being linked through a
management certificate.
