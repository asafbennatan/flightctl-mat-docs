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
Enrollment Request creation resolves the issuing CSR from the already
authenticated enrollment certificate by tenant-scoped exact-DER matching
against the CSR's retained issued certificate. The resolved row supplies the
CSR name for the optional `status.enrollmentCertificateName` reference.
A certificate-carried CSR-name extension is not required: revocation and policy
eligibility still require authoritative CSR state, so a signed name would not
remove the database dependency.
Device-supplied request-body fields are not trusted replacements.

A matching common name or the ER's device-management CSR is not sufficient
proof. A unique actual issuing-CSR match supplies the reference without
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
When revocation enforcement is enabled, failure to resolve the issuing CSR or
determine its revocation state fails closed. Otherwise, missing metadata alone
neither rejects an otherwise valid certificate nor prevents Enrollment Request
creation. Operational errors are not identity proof.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
Historical admissions without a stored issuing-CSR reference retain that
absence, not a separate origin classification. Unknown credential provenance
is not reconstructed from a management certificate or later polling.
