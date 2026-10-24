# Review follow-up

User correction: Compose parent bundles and Helm charts do not use image deltas; package preparation contributes neutral NotRequired. Nested workload images remain eligible. Do not add Compose/Helm packages to workload outcome aggregation. No integration tests.

Previously confirmed seams: Store behavior, prefetch, emitted application digest/outcome pairs. Provider Install/Collect and lifecycle Execute seams also confirmed by the user. These tests cover system boundaries through mocks; live Podman semantics remain untested by request.

## Work

- [x] Reproduce and fix mutable application-history retention through public Store methods (new regression red/green).
- [x] Compose/Helm top-level packages: ignore hints/discovery, prepare normally, neutral NotRequired; keep nested outcomes independent.
- [x] Missing parent image/artifact digest metadata must not prevent extraction/install; withhold only evidence.
- [x] Reuse cached nested targets after AfterUpdate cleared extraction bytes (outside-diff PR review).
- [x] Remove duplicated artifact volume preparation workflow; preserve existing Quadlet retention/cleanup behavior.
- [x] Bundle captured application attempt identity; centralize validation.
- [x] Pass existing provider logger into extractAppDataFromOCITarget instead of creating one.
- [x] Verify ImageMount classification against actual image/artifact semantics; fix if valid.
- [x] Verify state-version comment: retain schema migration if required rather than resetting blindly.
- [x] Extend persistence-failure Ensure/Update behavior if still blocking optional observation.
- [x] Update docs/spec for user correction and final behavior; unit tests/race/lint/docs, no integration.

## PR threads snapshot

- 4246472028 volume inspection cache: retained existing verified identity cache and its status coverage.
- 4246472034 missing retained parent extraction fallback: public Install coverage now verifies digest-known and digest-unknown re-extraction.
- 4246472057 unbounded pending history: OS active+pending protection already fixed; application mutable-key retention fixed above.
- 4267686219 disabled identity recording warning: existing canRecordIdentity guard fixed.
- 4267686256 preserve unchanged Quadlet artifact volume: shared preparer retains binding+CreatedAt+digest preservation; lifecycle tests pass.
- 4267686263 status persistence blocking removal: Remove remains best effort; new public Ensure/Update regressions prove installation continues without evidence after failed persistence.
- 4269990128 test behavior depending on names: explicit malformedID field already present.
- 4269990142 subtest names: existing When/it should names already present.
- 4269990150 hinted Quadlet artifact lacks persisted digest: current fallback records inspected artifact digest; user correction changes Compose only.
- 4271989310 ImageMount classification: Auto classification resolves image versus artifact from owning local store; public provider Install regression covers artifacts.
- 4271991075 logger creation: fix.
- 4272277766 state version: retained version 4 because lifetime-bound volume provenance changes persisted format; added migration rationale. Existing versions 1–3 migrate on load.
- 4272291066 duplicate queued task registration: existing refresh queued task path + regression fixed.
- 4273113753 parent identity metadata blocks extraction: same work item above, include images and artifacts.
- Outside-diff review 5520769609: reuse valid nested cache without retained appData.
- Outside-diff review 5520932814: update contradictory hinted-artifact docs (align with user correction).

No remote comments or thread-resolution actions authorized separately. Preserve current PR branch and all user work.

## Final review and validation

- Both final branch-review axes found no additional Standards or Spec findings.
- Package results remain neutral in scheduling and are excluded from persistent workload targets/results/history; a red/green prefetch regression verifies this.
- Affected application/lifecycle/provider, Store, and prefetch packages pass with race detection.
- Documentation lint and spelling pass. Final lint reports zero issues. Full unit suite completed 9,863 tests with two existing skips; affected packages also pass with race detection.
- Remote review threads remain unresolved; no replies or resolution actions were posted.

## Unreleased format correction

The earlier version-4 rationale was incorrect: the feature is unreleased. The format is version 1 only. Removed compatibility loading, version-1 evidence stripping, FIFO sequence migration fields and conversion, and lifetime-less evidence adoption. Migration-specific tests were removed; public Store regressions verify version-1 restart and rejection of unsupported formats.

## Latest full-branch and Chai follow-up

- [x] Distinct volume references count as observations independently of workload references; emitted-status regression covers their complete aggregate.
- [x] Providers look up retained parent bytes by generated application ID; real FromDeviceSpec/Install coverage covers Compose and Quadlet with known/unknown digests.
- [x] Installed parent digest is retained in emitted status; manager no longer overwrites it from OCI target cache.
- [x] Binding save errors after successful extraction are best effort; lifecycle Execute keeps prepared contents. Pre-mutation invalidation remains required.
- [x] Superseded application histories do not remain active merely because target keys match: captured attempt validation rejects stale writes and latest accepted pending content determines protection. Public Store tests cover changed/same attempt, incomplete collection, previous observations, active evidence, and restart.
- [x] OS history protects booted and latest accepted identities, releasing replaced stages with stable mutable target key; public restart regression verifies eviction.
- [x] Remove/reinstall clears the application volume-observation cache; removal/update behavior suites pass.
- [x] Six cache case names follow When ... it should ... convention.

Affected race tests, lint, docs lint and spelling pass. Initial full unit run hit existing systeminfo TestCollectCustomInfo 100ms script deadline; focused rerun passed, full suite recheck in progress. No integration tests.

Final validation: 9,873 unit tests, two existing skips; affected application/lifecycle/provider, Store, prefetch and OS race tests passed. Lint reports zero issues; docs lint and spelling pass. The existing 100ms systeminfo script test passed on focused and full-suite reruns. Cached unobserved content reused after a spec change remains protected. No integration tests ran.
