---
status: proposed
---

# Restricted CEL policies with exact-one-match enforcement

EnrollmentApprovalPolicy matching is boolean CEL over a closed, typed input
set — reported `serial`, `productSerial`, and `productUuid`, certificate name
and organization, and server-verified TPM status — restricted to a bounded
subset in which policy overlap is decidable.
Multiple enabled policies may share a certificate only when provably disjoint,
and admission requires exactly one passing policy.
Zero matches or unexpected multiple matches leave the Enrollment Request
pending with a reason; no implicit priority resolves a conflict.

Arbitrary key/value matching was rejected because device-reported keys are
spoofable and arbitrary expression overlap cannot be soundly decided by
sampling.
Implicit policy priority was rejected because it silently masks configuration
conflicts instead of surfacing them.
A single policy per certificate was rejected because disjoint commissioning
groups legitimately need separate static labels under one credential.
Candidate evaluation errors mark that candidate nonpassing without vetoing
another passing policy.

## Supported expression shapes

The typed environment separates three input sources, and only `reported.*` is
ordinary device-reported data:

- `reported.serial`, `reported.productSerial`, `reported.productUuid` —
  agent-reported, non-attested device data; the primary matching surface.
- `certificate.name`, `certificate.organizationID` — certificate-derived trust
  context, separate from reported data.
- `tpm.verified` — a server-verified boolean, separate from reported data; it
  gates on enrollment evidence and never describes the device or upgrades the
  assurance of reported identifiers.

Useful shapes for general policies:

```cel
// Fleet-scale commissioning group by serial prefix.
has(reported.serial) && reported.serial.startsWith("WEST-")
```

```cel
// Same group, but require verified TPM evidence as a separate gate.
has(reported.serial) && reported.serial.startsWith("WEST-") && tpm.verified
```

```cel
// Explicit group of known devices by productUuid.
// At least two values; singleton UUID policies are rejected.
has(reported.productUuid) && reported.productUuid in [
  "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
]
```

```cel
// Known values via finite membership (or == equality) on reported data.
has(reported.productSerial) && reported.productSerial in [
  "BATCH-A-001",
  "BATCH-A-002"
]
```

```cel
// Combining groups with boolean operators.
(has(reported.serial) && reported.serial.startsWith("WEST-")) ||
(has(reported.productUuid) && reported.productUuid in [
  "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
])
```

There is no regex, and none would make sense for `productUuid`: a UUID is
opaque with no site, batch, or factory structure to pattern-match, so a
well-formed-UUID regex matches every device and discriminates nothing.
More importantly, arbitrary regex overlap is undecidable, which would break
provable disjointness between enabled policies sharing a certificate.
Finite lists keep set intersection decidable, which is exactly why grouped
membership is the supported form for UUID matching.

`certificate.*` is available as context, but the certificate is already the
mandatory policy boundary through `spec.certificateName`; expressions
typically gate on reported data plus `tpm.verified` rather than re-selecting
the certificate.
