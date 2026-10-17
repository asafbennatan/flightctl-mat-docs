Status: ready-for-agent

# EDM-4868 Part G — Administrator API, CLI, and documentation

## Problem Statement

Fleet administrators and security officers need to manage automatic Enrollment Request approval, understand why requests remain pending, configure policy quotas, revoke enrollment credentials, and trace the requests and devices affected by a credential. The core behavior is defined by Parts A–F, but Flight Control does not yet expose those capabilities through a consistent administrator API, CLI, and operator documentation. The UI is intentionally a separate deliverable in its own repository.

## Solution

Expose automatic approval through Flight Control’s existing resource interfaces rather than a parallel administrator framework. EnrollmentApprovalPolicy uses the normal resource lifecycle commands, policy status exposes the server-owned enrollment count, and inventory and traceability use field selectors on existing Enrollment Request and Certificate Signing Request collections. Certificate issuance reports the actual CSR name and expiry, and certificate revocation becomes a subcommand of the existing certificate command. User documentation explains the trust model, policy semantics, quota, expiry, revocation, affected-device tracing, and the distinction between enrollment credentials and device management certificates.

## User Stories

1. As a fleet administrator, I want to create an EnrollmentApprovalPolicy through the standard resource interface, so that I can opt into automatic approval without learning a new API.
2. As a fleet administrator, I want to list and read EnrollmentApprovalPolicies, so that I can audit the current automatic approval configuration.
3. As a fleet administrator, I want to replace a policy declaratively, so that I can manage commissioning configuration as code.
4. As a fleet administrator, I want to edit a policy interactively, so that I can make a targeted change without replacing the entire resource.
5. As a fleet administrator, I want to delete a policy, so that I can retire an automatic approval rule.
6. As a fleet administrator, I want policy edits to preserve committed Enrollment Request history, so that changing future behavior does not rewrite past approvals.
7. As a fleet administrator, I want the CLI’s existing edit command to remain the JSON Patch path, so that I do not need a separate patch command.
8. As a fleet administrator, I want the policy table to show enabled state, certificate binding, approval limit, enrollment count, and approval window, so that I can understand policy status at a glance.
9. As a fleet administrator, I want to read the policy status count without editing it, so that I can audit how many devices a policy has automatically approved.
10. As a fleet administrator, I want to change an approval limit, so that I can stop or expand automatic onboarding without creating a new policy.
11. As a fleet administrator, I want omitted and zero approval limits to remain distinct, so that unlimited and blocked automatic approval are not confused.
12. As a fleet administrator, I want the available approval count computed from the limit and enrollment count, so that the system does not store a second, drift-prone counter.
13. As a fleet administrator, I want to see why an Enrollment Request is pending or rejected, so that I can decide whether to fix a policy or approve manually.
14. As a fleet administrator, I want to distinguish automatic approvals from manual approvals, so that I can tell whether a policy or a person admitted a device.
15. As a fleet administrator, I want to identify the policy that approved an Enrollment Request, so that I can trace an automatic approval to its configuration.
16. As a fleet administrator, I want to identify the enrollment credential that authenticated an Enrollment Request, so that I can trace requests back to the issuing CSR.
17. As a fleet administrator, I want to list Enrollment Requests linked to a policy, so that I can see the devices a policy admitted.
18. As a fleet administrator, I want to list Enrollment Requests linked to an enrollment credential, so that I can see the paper trail for a certificate.
19. As a fleet administrator, I want to navigate from an approved Enrollment Request to its same-named Device, so that I can identify affected devices without a new relationship resource.
20. As a security officer, I want to revoke an enrollment credential with `flightctl certificate revoke`, so that I can stop new devices from using it without introducing a top-level revoke command.
21. As a security officer, I want to supply a revocation reason, so that operators and auditors can understand why the credential was revoked.
22. As a security officer, I want revocation to be idempotent, so that retrying the operation cannot duplicate work or overwrite the original reason, actor, or time.
23. As a security officer, I want to see the revocation actor, time, and reason, so that I can audit the action.
24. As a security officer, I want the CLI to state that revocation blocks new enrollment but does not evict enrolled devices, so that I do not mistake flagging for removal.
25. As a fleet administrator, I want certificate issuance to report the actual CSR name, so that I can use that exact name in a policy’s certificate binding.
26. As a fleet administrator, I want certificate issuance to report certificate expiry, so that I can distinguish certificate lifetime from the optional automatic approval window.
27. As a fleet administrator, I want to list enrollment credentials by signer, so that I can inventory the credentials eligible for automatic approval.
28. As a fleet administrator, I want credential inventory to preserve existing CSR behavior, so that enrollment credentials do not require a new top-level resource.
29. As an API consumer, I want generated clients to include the policy, provenance, issuance, and revocation contracts, so that integrations remain type-safe.
30. As an OT operator, I want documentation that explains opt-in setup, so that I can enable automatic approval deliberately.
31. As an OT operator, I want documentation that explains the enrollment credential trust model, so that I understand what automatic approval does and does not prove.
32. As an OT operator, I want documentation that distinguishes server-verified TPM evidence from agent-reported identifiers, so that reported fields are not presented as attested facts.
33. As an OT operator, I want documentation that explains policy quotas and issuance-based approval windows, so that I can bound credential abuse without expecting per-minute rate limiting.
34. As an OT operator, I want documentation that explains revocation and affected-device flagging, so that I can respond to a compromised credential without expecting devices to be evicted.
35. As an OT operator, I want documentation that explains manual fallback, so that I know unmatched or blocked requests remain available for human approval.
36. As an OT operator, I want documentation that explains the label seal, so that I can predict which incoming labels are preserved and which administrator labels win.
37. As an OT operator, I want documentation that distinguishes the enrollment CSR from the device management CSR, so that I do not confuse bootstrap identity with post-enrollment identity.
38. As an OT operator, I want CLI examples for policy management, inventory, traceability, and revocation, so that I can operate the feature without reading the OpenAPI specification.

## Implementation Decisions

- Part G is limited to the Flight Control core repository: API contracts, generated clients, CLI behavior, and user documentation. The UI is a separate follow-up in the UI repository.
- EnrollmentApprovalPolicy remains a standard core resource. It is exposed through the existing generic resource machinery for list, get, create, replace, patch, delete, and status reads.
- The CLI uses the existing generic commands for policy management: get, apply, edit, and delete. No new patch command is added because edit already provides the JSON Patch path.
- Policy table output includes the policy name, enabled state, certificate name, approval limit, enrollment count, and automatic approval window.
- Policy status remains server-owned. The CLI displays the committed enrollment count and computes any remaining count from the configured limit; it does not store or submit a derived remaining-count field.
- Enrollment Request tables and detail output expose the approval policy and enrollment certificate references, along with existing approval and condition information.
- The following field selectors are supported on existing collections:
  - Certificate Signing Request `spec.signerName`
  - Enrollment Request `status.enrollmentCertificateName`
  - Enrollment Request `status.enrollmentPolicyName`
- The field selectors use the existing selector resolver and list machinery. They do not introduce bespoke query endpoints or a new relationship resource.
- Store indexes support the new selector paths so credential inventory and policy or revocation tracing do not become unbounded scans.
- `status.enrollmentCertificateName` is a reference to the issuing enrollment CSR’s `metadata.name`. It is not a certificate fingerprint, common name, or device management CSR name.
- Explain that new Enrollment Requests obtain this exact name from the authenticated leaf's issuer-attested credential binding, not from a caller-supplied field or a CSR discovery query. Signed identity does not prove current authorization; primary-state revocation and missing-record barriers still apply.
- Policy-linked devices are found by filtering Enrollment Requests by policy or credential and then using the existing same-name Enrollment Request-to-Device relationship.
- The certificate command is organized into `certificate request` and `certificate revoke` subcommands while preserving the existing request behavior.
- Certificate request output reports the actual, possibly uniquified CSR name and the certificate expiry while preserving the existing agent configuration output.
- Certificate revoke is exposed as `flightctl certificate revoke`, not as a top-level `flightctl revoke` command. Its required inputs are the issuing CSR name and revocation reason; it invokes the Part E revocation contract and reports the immutable revocation result. It does not add an un-revoke operation.
- Clients supply the configured enrollment signer value when filtering credential inventory. This part does not add a server-resolved signer-name field.
- Generated API clients and types are updated from the OpenAPI specification so external consumers and the later UI work can use the same contracts.
- User documentation adds a dedicated automatic approval guide and updates the existing enrollment, certificate, security, API-resource, and CLI references.
- Documentation explains opt-in setup, policy matching, TPM as a separate trust gate, reported-field assurance limits, label sealing, quota, issuance-based windows, revocation, flagging, manual fallback, and non-eviction.
- Document the explicit compatibility boundary: enrollment leaves without supported signed identity cannot start or continue new enrollment operations and have no legacy database-discovery fallback. Operators obtain a compatible newly issued credential under a new CSR name and recreate unbound pending requests; historical unknown admissions remain `LegacyUnknown`. Do not re-sign or backfill old issuance evidence. Existing devices and management-certificate renewal remain unchanged.
- Documentation uses the mapped glossary terminology for Enrollment Request, issuing CSR, EnrollmentApprovalPolicy, automatic approval, trust gate, enrollment revocation, and flagging without eviction.
- No new event type, public authorization interface, credential resource, admission route, or general mutation framework is introduced.

## Testing Decisions

- Good tests assert externally visible API, CLI, selector, and documentation behavior. They do not test private helper names, SQL text, lock ordering, or internal formatting helpers.
- The primary API seam is the existing resource route interface for policies, Enrollment Requests, and Certificate Signing Requests.
- Selector tests verify that the new field names resolve to the correct JSON paths and types and remain consistent with the API schema.
- Store integration tests exercise the new selectors with pagination and confirm that the supporting indexes are used without coupling tests to a specific query plan.
- CLI command tests cover policy get, apply, edit, and delete; table output; issuance output; and certificate revoke.
- CLI tests assert the actual user-visible command behavior and generated request payloads, not internal helper call sequences.
- Certificate tests verify that issuance reports the actual CSR name and expiry, that the existing agent configuration output remains usable, and that revoke maps validation, success, and idempotent-retry responses correctly.
- API serialization tests cover the new selector query parameters, policy status, ER provenance fields, CSR issuance metadata, and revocation response shape.
- Documentation checks cover the new and updated user topics, CLI examples, and glossary terminology.
- Prior art is the repository’s existing generic resource command tests, selector schema tests, store integration tests, CLI table tests, and user-documentation checks.

## Out of Scope

- UI implementation, routes, components, generated UI types, permissions, and Cypress tests; those belong to the separate UI repository.
- A new `patch` command; the existing `edit` command is the JSON Patch interface.
- New admission, matching, quota, revocation, TPM, or flagging logic; those are owned by Parts A–F.
- A new credential resource, fingerprint field, or public certificate identity.
- Bespoke policy-device, credential-device, or affected-device query endpoints.
- CRL or OCSP infrastructure.
- Un-revocation or revocation of management and service-client certificates.
- Device eviction, quarantine, or changes to management-certificate renewal.
- The 5000-device scale demonstration.

## Further Notes

- This part is an adapter over the settled Parts A–F contracts; it intentionally adds no new approval semantics.
- The UI follow-up should regenerate its types from the merged core OpenAPI specification before implementing policy authoring, credential inventory, revocation, and traceability screens.
- `flightctl edit` is the existing user-facing equivalent of a patch operation and already uses JSON Patch with resource-version protection.
