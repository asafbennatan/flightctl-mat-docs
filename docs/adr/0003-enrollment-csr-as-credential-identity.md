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

Only when those signed details are absent, attempt to recover them from the
issuing enrollment CSR within the authenticated tenant/organization. Decode its
retained issued certificate and match the exact presented leaf; a matching
common name or the ER's device-management CSR is not sufficient proof.
A unique actual issuing-CSR match supplies its existing identity and recoverable
details without certificate reissuance. Such a request is not legacy solely
because its certificate predates signed metadata; other policy eligibility
requirements still apply, and missing data must not be invented.

If no unique trustworthy match is available, create the Enrollment Request
without unrecoverable details and explicitly mark it as legacy.
Legacy Enrollment Requests are ineligible for EnrollmentApprovalPolicy approval.
Missing metadata alone neither rejects an otherwise valid certificate nor
prevents Enrollment Request creation; ordinary certificate/mTLS authentication,
existing revocation checks, and Enrollment Request persistence are unchanged.
Operational errors are not identity proof; existing error handling is unchanged.
This recovery applies to new ER creation with the presented leaf, not retroactive
reconstruction of stored ERs that lack that evidence.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
Historical admissions whose issuing CSR identity cannot be reconstructed
remain explicitly `LegacyUnknown` rather than being linked through a
management certificate.
