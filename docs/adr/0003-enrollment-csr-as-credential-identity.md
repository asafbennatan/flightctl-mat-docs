---
status: proposed
---

# Reuse the enrollment CSR as the credential identity

The tenant-local `metadata.name` of the existing enrollment-signer
CertificateSigningRequest is the enrollment-credential identity.
The issuer signs the exact CSR name into the enrollment leaf from the
authoritative issuance resource, so Enrollment Request creation can obtain
its binding from authenticated context without a CSR identity-discovery
database read.
CSR status retains issuance time, issued certificate bytes, and revocation
state; no EnrollmentCertificate resource or second primary identifier is added.

## Considered Options

A dedicated EnrollmentCertificate resource would duplicate CSR inventory and
issuance while requiring migration of existing credentials.
A fingerprint or UUID identity would add a second identifier beside the
existing tenant-local primary key.
Discovering identity by searching stored certificate bytes was rejected
because the issuer already knows the exact CSR name when signing.
Deriving it from the common name was rejected because enrollment common names
are normalized and need not preserve the exact resource name.
HTTP fields, request-body names, and caller-supplied CSR extensions cannot
establish this binding.

This proposal supersedes the lookup-based binding and legacy identity-recovery
guidance in the parent technical design referenced by the grill record.
The parent draft's common-name candidate search is a historical alternative,
not an additional resolution path. This ADR does not assert that the separate
parent design, PRD, or testplan has already been amended or approved.

## Consequences

`EnrollmentApprovalPolicy.spec.certificateName` and Enrollment Request status
reference CSR names.
The reserved signed identity extension is issuer-controlled and read only
after normal chain, enrollment-signer, and tenant checks.
Missing, malformed, duplicate, conflicting, or unsupported identity metadata
fails closed; there is no legacy database-discovery fallback.
Issuance rejects caller injection of the reserved extension and verifies the
binding on the resulting leaf before publishing it with immutable server-owned
issuance time.
The [issuance specification](../../.scratch/edm-4868-csr-issuance-metadata/spec.md)
defines the extension contract and compatibility boundary.

This replaces absent/ambiguous leaf-to-CSR discovery with unambiguous
issuer-attested binding, not with a claim that signed metadata proves current
database state.
The [revocation barrier](0004-enrollment-revocation-at-mtls-without-eviction.md)
still checks authoritative state on every handshake, including resumption,
and inside enrollment mutations using the attested tenant/name as its key.
It rejects missing or revoked records, unavailable state, and a leaf that
does not match the retained issued certificate bytes.
That keyed state check is not identity discovery and does not add a second
identity lookup during Enrollment Request creation.

Names referenced by policies or retained enrollment and revocation history are
reserved so deletion and recreation cannot retarget relationships.
An issued credential's name also remains reserved while the credential can
authenticate; replacement must not retarget a still-valid signed binding.
Old leaves without the required signed identity are incompatible with new
enrollments: operators must obtain a compatible credential under a new CSR
name, not rewrite existing issuance evidence or backfill the old leaf.
Historical admissions whose enrollment credential CSR identity cannot be
reconstructed remain explicitly `LegacyUnknown` rather than being linked
through a management certificate.
Existing enrolled devices and management-certificate renewal remain unchanged;
enrollment revocation is not eviction.
