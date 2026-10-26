Status: ready-for-agent

# EDM-4868 — Reuse the enrollment CSR as the credential identity

## Problem Statement

Enrollment approval policies, revocation, and affected-device traceability need a stable identity for the enrollment credential that issued a device’s bootstrap certificate. Introducing a separate credential resource would duplicate inventory, issuance, and signer flow, while a fingerprint or UUID would add a second identifier beside the existing tenant-local primary key.

## Solution

Reuse the existing enrollment-signer CertificateSigningRequest’s tenant-local name as the enrollment-credential identity. Extend that CSR’s status with issuance time and revocation state, and let Enrollment Requests carry an optional reference to the issuing CSR. Enrollment authentication resolves the exact presented leaf through the authenticated tenant’s private certificate-digest index and carries the unique CSR name in the enrollment identity; Enrollment Request creation persists that name. No new credential resource, fingerprint, or UUID is introduced.

## User Stories

1. As a fleet administrator, I want each enrollment credential to have a stable identity, so that policies and audit records can reference it consistently.
2. As a fleet administrator, I want the existing CSR name to be that identity, so that I do not have to manage a second resource.
3. As a fleet administrator, I want issuance and revocation state on the same CSR, so that credential lifecycle information stays together.
4. As a security officer, I want the authenticated certificate to resolve to its exact issuing CSR, so that a common name or management certificate cannot impersonate another credential.
5. As a security officer, I want names referenced by policies or retained history to be reserved, so that deletion and recreation cannot retarget relationships.
6. As a security officer, I want revocation state exposed through the CSR’s public status, so that readers can inspect it without a separate lookup.
7. As an auditor, I want Enrollment Requests to record their issuing CSR when known, so that I can trace admissions back to a credential.
8. As an auditor, I want historical requests without a stored reference to remain explicitly unknown, so that the system does not fabricate provenance.
9. As an API consumer, I want the existing CSR resource to remain the credential inventory, so that tooling does not need a new collection.
10. As an API consumer, I want the CSR API to remain unchanged apart from added status fields, so that existing automation keeps working.
11. As a Flight Control engineer, I want identity resolution to fail closed when the exact issuing CSR cannot be established, so that ambiguity never becomes authorization.
12. As a Flight Control engineer, I want the design to avoid a new origin classification, so that legacy requests remain represented by the absence of a reference.

## Implementation Decisions

- The existing enrollment-signer CSR’s tenant-local name is the enrollment-credential identity.
- No EnrollmentCertificate resource, fingerprint identity, or credential UUID is introduced.
- Enrollment Request status gains an optional reference to the issuing CSR.
- The reference comes from the CSR name carried in the authenticated enrollment identity, not from device-supplied request fields.
- Enrollment authentication matches the exact presented leaf DER against the private certificate-digest index within the authenticated tenant/organization and requires exactly one decoded retained-certificate match. The digest index covers credentials issued before and after this design.
- Names referenced by policies or retained enrollment and revocation history are reserved against deletion and recreation.
- Issuance time and revocation state are exposed through the CSR’s existing public status.

## Testing Decisions

- Good tests assert externally visible CSR and Enrollment Request behavior, not private resolver internals.
- The primary seam is the existing CSR status and Enrollment Request creation path.
- Verify that an authenticated enrollment certificate resolves to the correct issuing CSR.
- Verify that a unique exact-leaf match resolves to the correct CSR and that an unresolved leaf cannot fabricate a reference.
- Verify that reserved names cannot be retargeted through deletion and recreation.
- Prior art is the existing CSR issuance and Enrollment Request service tests.

## Out of Scope

- A new credential resource or identity type.
- Backfilling historical Enrollment Requests with inferred provenance.
- Using a management certificate to identify a bootstrap credential.
- Changing certificate issuance or signer authorization.

## Further Notes

- This decision is recorded in ADR 0003.
