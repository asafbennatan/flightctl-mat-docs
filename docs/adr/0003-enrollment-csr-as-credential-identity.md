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
The enrollment certificate does not embed the CSR name. Enrollment
authentication resolves the exact presented leaf to its issuing enrollment CSR
by matching the leaf DER against the private certificate-digest index within
the authenticated tenant/organization. The resolved CSR name is carried in the
authenticated enrollment identity, and Enrollment Request creation persists it
as the optional `status.enrollmentCertificateName` reference.
Device-supplied request-body fields are not trusted replacements.

A matching common name, serial number, or the ER's device-management CSR is not
sufficient identity proof. Exactly one issuance record must match the presented
leaf; ambiguity or no match leaves the reference absent. Missing identity must
not be invented. The digest index applies equally to credentials issued before
and after this design, so resolution does not require certificate reissuance.

Embedding the CSR name in the certificate as another issuer-owned extension was
rejected. Enrollment authentication already resolves the exact leaf to obtain
the CSR's current approval and revocation state, so the extension would add a
second identity channel that can disagree with CSR inventory.

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
Historical admissions without a stored issuing-CSR reference retain that
absence, not a separate origin classification. Unknown credential provenance
is not reconstructed from a management certificate or later polling.
