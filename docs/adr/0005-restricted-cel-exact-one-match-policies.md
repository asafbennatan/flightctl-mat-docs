---
status: proposed
---

# Restricted CEL policies with exact-one-match enforcement

EnrollmentApprovalPolicy matching is boolean CEL over a closed, typed view of
the Enrollment Request's reported device status — the identifier fields under
`spec.deviceStatus.systemInfo` — restricted to a bounded subset in which
policy overlap is decidable.
TPM verification and the certificate are not CEL inputs: the certificate is
already the mandatory policy boundary through `spec.certificateName`, and the
TPM requirement is a separate boolean policy field alongside it.
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

CEL runs only on the data the Enrollment Request already reports, under its
existing paths — most of it under `spec.deviceStatus.systemInfo`:

- `spec.deviceStatus.systemInfo.productSerial` and
  `spec.deviceStatus.systemInfo.productUuid` — built-in, agent-reported,
  non-attested identifiers.
- `spec.deviceStatus.systemInfo.customInfo` — the existing user-defined map;
  a generic `serial` key may be configured there.

The certificate and the TPM requirement are separate policy fields
(`spec.certificateName` and its TPM counterpart), which is why neither appears
inside the expression.

Useful shapes for general policies:

```cel
// Fleet-scale commissioning group by productSerial prefix.
has(spec.deviceStatus.systemInfo.productSerial) &&
spec.deviceStatus.systemInfo.productSerial.startsWith("WEST-")
```

```cel
// Configured generic serial, stored in the existing customInfo map.
'serial' in spec.deviceStatus.systemInfo.customInfo &&
spec.deviceStatus.systemInfo.customInfo['serial'].startsWith("WEST-")
```

```cel
// Explicit group of known devices by productUuid.
// At least two values; singleton UUID policies are rejected.
has(spec.deviceStatus.systemInfo.productUuid) &&
spec.deviceStatus.systemInfo.productUuid in [
  "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
  "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
]
```

```cel
// Known values via finite membership (or == equality).
has(spec.deviceStatus.systemInfo.productSerial) &&
spec.deviceStatus.systemInfo.productSerial in [
  "BATCH-A-001",
  "BATCH-A-002"
]
```

```cel
// Combining groups with boolean operators.
(has(spec.deviceStatus.systemInfo.productSerial) &&
 spec.deviceStatus.systemInfo.productSerial.startsWith("WEST-")) ||
(has(spec.deviceStatus.systemInfo.productUuid) &&
 spec.deviceStatus.systemInfo.productUuid in [
   "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
   "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"
 ])
```

Requiring verified TPM is done through the policy's separate TPM field, never
by adding `tpm.verified` to the expression; a TPM-less device simply qualifies
under policies that do not set that field.

There is no regex, and none would make sense for `productUuid`: a UUID is
opaque with no site, batch, or factory structure to pattern-match, so a
well-formed-UUID regex matches every device and discriminates nothing.
More importantly, arbitrary regex overlap is undecidable, which would break
provable disjointness between enabled policies sharing a certificate.
Finite lists keep set intersection decidable, which is exactly why grouped
membership is the supported form for UUID matching.

The certificate never appears in CEL either: `spec.certificateName` is the
mandatory policy boundary, and an expression cannot select another credential
or organization.

## Implementation reuse

The existing CEL evaluator in `internal/service/labelsyncmapping` is
Device-oriented, not ER-oriented: `ActivateDevice` builds activation roots
from a Device, and its environment exposes dynamic `metadata`/`spec`/`status`
with optional types, comprehensions, and semver — the broad activation this
decision excludes.
Reuse its machinery, not its environment: the cel-go dependency, the
Parse → Check → Program pipeline with cost limits, the LRU program cache,
synchronous CRUD-time validation, and the JSON activation round-trip.
The net-new constructs are the restricted typed environment over ER
`spec.deviceStatus.systemInfo`, boolean-only output validation, an AST subset
validator, a cross-policy disjointness analyzer, and an ER activation builder.
Extract the domain-independent pipeline, cache, and activation helper into a
shared internal CEL runtime package; label-sync and enrollment each construct
their own environment, and two real consumers justify the seam.
