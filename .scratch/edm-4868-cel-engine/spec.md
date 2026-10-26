Status: ready-for-agent

# EDM-4868 Part A — Shared CEL runtime and enrollment policy matching engine

## Problem Statement

EDM-4868 adds enrollment approval policy matching, but Flight Control's only CEL evaluator today serves label-sync. It is Device-oriented, exposes broad dynamic roots with optional types, comprehensions, and semver, and returns scalar or map results. Enrollment policy matching needs the opposite: a restricted typed view of the identifiers an Enrollment Request already reports, boolean-only results, provable disjointness across enabled policies sharing a certificate, and exact-one-match evaluation. Building this on the existing environment would let policy expressions use constructs whose overlap cannot be decided, and duplicating the compile/cache machinery would leave two CEL pipelines to maintain.

## Solution

Extract the domain-independent CEL machinery into a shared, consumer-agnostic runtime — environment construction, the parse/check/program pipeline, cost limits, an LRU program cache, staged errors, and activation normalization. Keep label-sync's existing interface unchanged, backed by that runtime. Build a new enrollment policy matching engine on top of it that validates the restricted expression subset, proves enabled policies per certificate are disjoint, and evaluates exact-one-match during admission with per-candidate diagnostics.

## User Stories

1. As a fleet administrator, I want policy match expressions to run only on the identifiers an Enrollment Request already reports, so that I can reason about exactly what my policy can see.
2. As a fleet administrator, I want to group devices by productSerial or configured serial prefixes, so that commissioning batches map to policies without per-device rules.
3. As a fleet administrator, I want to select explicit groups of known devices by productUuid lists, so that small known fleets can share a policy.
4. As a fleet administrator, I want singleton productUuid policies rejected, so that no one creates one policy per device.
5. As a fleet administrator, I want policy expressions to be boolean, so that a policy unambiguously matches or does not match a request.
6. As a fleet administrator, I want actionable validation errors when my expression leaves the supported subset, so that I can fix it without reading CEL internals.
7. As a fleet administrator, I want to require TPM verification through a separate policy field, so that trust gating is explicit and never disguised as reported data.
8. As a fleet administrator, I want the certificate selected through a dedicated policy field, so that an expression can never select another credential or organization.
9. As a fleet administrator, I want multiple enabled policies per certificate when they are provably disjoint, so that commissioning groups can carry different static labels under one credential.
10. As a fleet administrator, I want overlap rejection to name the conflicting policy, so that I can fix the right expression.
11. As a security officer, I want enabled policies per certificate to be provably disjoint before they can be enabled, so that no request can ever be admitted by multiple policies.
12. As a security officer, I want exact-one-match enforced at runtime even if configuration slips past validation, so that ambiguity leaves a request pending rather than picking a winner.
13. As a security officer, I want a candidate evaluation error to make only that candidate nonpassing, so that one broken policy cannot veto or approve on behalf of another.
14. As a security officer, I want bounded expression size, clause count, enabled-policy count, and execution cost, so that policy evaluation cannot exhaust service resources.
15. As a security officer, I want no regex, arithmetic, comprehensions, general negation, arbitrary functions, or dynamic field selection, so that overlap remains decidable and the surface stays reviewable.
16. As a security officer, I want TPM status to come only from the server-verified enrollment condition, so that a device can never satisfy a trust requirement by declaring it.
17. As an OT operator, I want per-policy pending diagnostics, so that I can see why a request did not auto-approve and whether manual approval is available.
18. As an OT operator, I want issuance-window eligibility decided inside matching with an injectable clock, so that window expiry is deterministic and testable.
19. As an OT operator, I want the auto-approval window boundary to keep a request eligible exactly at the boundary and treat negative elapsed time as ineligible, so that behavior is unambiguous.
20. As a Flight Control engineer, I want one shared compile/cache pipeline, so that CEL version upgrades, cost limits, and cache fixes happen in one place.
21. As a Flight Control engineer, I want each evaluator to own its own program cache, so that the same expression string compiled against two environments can never collide.
22. As a Flight Control engineer, I want staged errors that distinguish parse, check, output, program, evaluate, and convert failures, so that callers can return precise statuses.
23. As a Flight Control engineer, I want label-sync's evaluator interface to stay unchanged, so that its callers and test suite survive the extraction without migration.
24. As a Flight Control engineer, I want the shared runtime to stay consumer-agnostic, so that adding a consumer never edits the runtime's knowledge of its siblings.
25. As a Flight Control engineer, I want CEL to remain the only runtime evaluator, so that static analysis exists only for configuration validation and never drifts from evaluation semantics.
26. As the enrollment admission service, I want one matching call that takes the current locked policy set and the Enrollment Request, so that admission does not re-implement matching, disjointness, or diagnostics.
27. As a label-sync maintainer, I want the existing label-sync behavior preserved exactly, so that the extraction is invisible to my feature.

## Implementation Decisions

- Build a shared, consumer-agnostic CEL runtime module that owns environment construction, the parse → check → program pipeline, cost limits, a per-evaluator LRU program cache (caching successes and compile errors), staged error wrapping, and JSON activation normalization.
- The shared runtime exposes a typed evaluator parameterized by result type, with an output-contract seam (validate output type, handle missing results, convert values). Two real adapters justify this seam: label-sync's scalar/map/none result and enrollment's boolean-only result.
- The shared runtime exposes an analysis operation returning the checked expression AST for enrollment's subset validation and disjointness analysis. This is a narrow, deliberate leak; no generic AST-validator extension point exists.
- Each evaluator owns its own cache, keyed by expression string within that evaluator only. Cross-environment collision is impossible by construction; there is no dialect or consumer-identity parameter anywhere in the shared runtime.
- cel-go remains the only CEL engine dependency. It is in-process pure computation; no port, adapter, or mock around it is justified. Tests run the real engine through module interfaces.
- Keep label-sync's existing evaluator interface exactly as-is, implemented as an adapter over the shared typed evaluator. Its environment (dynamic roots, optional types, two-variable comprehensions, semver) moves with it; no caller migration and no test rewrite.
- Build an enrollment policy matching engine with two operations: validate an enabled policy set, and match an Enrollment Request against the current locked policy set. Validation is compile-and-discard internally; there is no separate prepare/compile step in the caller interface.
- The match operation takes the whole current policy set for the certificate, filters enabled policies itself, and returns an outcome — no policies, no match, exactly one match, ambiguous, or all candidates exhausted — plus the matching policy, conflicting policy names, and per-policy diagnostics. It receives issuance time and an injected clock for window eligibility.
- The final error return means the engine could not establish a sound result; callers must leave the request pending rather than reinterpret it as no match. TPM gates, hooks, quota, revocation, and the label seal stay outside the engine.
- CEL runs only on the Enrollment Request's existing reported device-status paths — productSerial, productUuid, and a configured generic serial in customInfo. There is no alias namespace; expressions use the request's real paths.
- The certificate and the TPM requirement are separate policy fields, not CEL inputs. The certificate is the mandatory policy boundary; the TPM requirement gates on the completed server-owned verified condition; TPM-less devices qualify under policies that do not set it.
- The supported expression subset is boolean literals, conjunction/disjunction/parentheses, typed equality against literals, finite string membership, startsWith on serial/productSerial, and presence guards. productUuid allows only grouped membership of at least two values. Identifier comparisons never match missing values; presence guards are available.
- Disjointness analysis normalizes each checked AST into bounded logical clauses and checks every cross-policy pair. Intersections of finite sets, exact strings, prefixes, and booleans are decidable; incompatible literals, prefixes, or booleans, or empty set intersections, establish disjointness. Unprovable overlap is rejected.
- Runtime evaluation runs every enabled policy with no precedence, priority, or first-match selection. A candidate-local error, cost overrun, invalid stored expression, elapsed window, or unknown issuance time makes that candidate nonpassing with a diagnostic, and evaluation continues.
- Example engineering bounds: 4 KiB expression source, 32 normalized clauses, 32 enabled policies per certificate, and a bounded execution cost. Expressions outside the subset fail validation with actionable errors, never silent approximations.
- No second runtime matcher: CEL is the evaluator; the clause-normalized static analysis exists only for configuration validation and is tested together with CEL semantics.
- Migration order: extract the shared runtime from label-sync first with no interface change, then build the enrollment engine on top.

## Testing Decisions

- Good tests assert external behavior through a module's interface and survive internal refactors. They never assert on cache internals, AST shapes, or other implementation details.
- Three seams, confirmed with the user:
  - **Enrollment matching engine (primary, new)**: validate-enabled-set and match behavior — subset acceptance and rejection, boolean-only output, disjointness acceptance and rejection with conflicting policy names, exact-one-match, ambiguity, candidate-error isolation, window boundary and negative-elapsed behavior, diagnostics, and sound-error pending semantics.
  - **Label-sync evaluator (existing, regression only)**: the existing evaluator test suite runs unchanged against the extracted implementation, proving the shared runtime preserves behavior. No new tests at this seam beyond the existing suite.
  - **Shared CEL runtime (internal machinery)**: per-evaluator cache isolation, concurrency safety, staged error stages, cost limits, and activation normalization. Consumer-visible behavior is not retested here.
- Prior art: the existing label-sync evaluator test suite (table-driven, extensive) for expression semantics; existing service handler test patterns for caller-facing behavior.
- Window tests inject a clock; no time-dependent test sleeps.
- The disjointness analyzer and CEL runtime semantics are tested together so static analysis cannot drift from evaluation.

## Out of Scope

- The EnrollmentApprovalPolicy resource, its CRUD service, store, status subresource, and set-validation-under-CSR-lock orchestration (Part B, designed separately).
- The admission transaction, quota accounting, label seal, Enrollment Request provenance fields, and condition/reason persistence (Part C).
- CSR issuance-time and revocation status, name retention, and signer-filtered inventory (Parts D–E).
- mTLS revocation enforcement, pending-request rejection, and device flagging (Part E).
- TPM challenge machinery itself (existing; only the separate policy gate is in scope here).
- REST routes, CLI, UI, operator/security documentation, the 5000-device scale demonstration, and hardening evidence (Parts G–H).
- Changing label-sync's caller-facing interface or tightening its environment.
- Arbitrary CEL, regex matching, new per-device identity mechanisms, or a pluggable CEL engine.

## Further Notes

- Respects ADR 0005 (restricted CEL with exact-one-match), ADR 0008 (issuance-based window), and the Enrollment auto-approval glossary terms: exact-one-match, provably disjoint, auto-approval window, and TPM verified.
- The companion PRD and technical design live in the planning-docs repository; prerequisite product/security signoff remains open and is not granted by this spec.
- Recommended numeric window/limit values and final resource bounds remain open stakeholder questions recorded in the design document.
