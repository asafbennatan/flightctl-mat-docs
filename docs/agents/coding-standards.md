# Coding Standards

Flight Control's coding standards are layered:

- **Universal standards** apply to every code change.
- **Area standards** apply only when you touch that area.

Read the universal standards first, then read the section for the area you are changing.

## Universal standards

1. Reuse established patterns and keep changes focused. Avoid unrelated refactors.
2. Prefer provider-owned interfaces. Create a new interface only for an owning area, multiple production implementations, a system perimeter, or an explicit request.
3. Do not use function parameters or function-typed fields as dependency injection. Use a provider-owned interface at the real seam—or the concrete service type when no interface is warranted—and test that seam with generated mocks.
4. Validate required nil-able dependencies in new constructors. Preserve existing constructor signatures unless their contract is deliberately being migrated.
5. Return mutation results atomically when a database mutation determines the resulting state. Avoid re-reading a row only to discover what the mutation wrote.
6. Use table-driven tests with `testify/require` and test names in the form “When … it should …”.
7. Keep unit tests beside the code under test and free of external service dependencies. Use integration and e2e harnesses for those boundaries.
8. Never hand-edit generated code. Change the source OpenAPI, proto, or hand-written type file and regenerate.
9. Prefer guard clauses and early returns; avoid nested or chained `if/else` when a clearer flat structure is possible, and keep the success path flat.

## Context and cancellation

10. Use `context.Context` when an operation can block, performs I/O, crosses a service or process boundary, or needs cancellation, deadlines, or tracing. When accepted, make it the first parameter, never store it in a struct or global, and honor cancellation on I/O and long-running work.

## Error handling

11. Wrap underlying errors with `%w` when adding context, use domain errors for decisions, avoid string matching, and map user-facing status at the boundary.

## Concurrency

12. Prefer sequential code. Use concurrency only when it improves throughput or responsiveness, and give every concurrent operation a clear owner, cancellation path, and cleanup.

## Resource cleanup

13. Handle every `Close`, `Cancel`, rollback, or stop path with `defer` or an explicit ownership rule. Treat leaks as bugs.

## Observability

14. Add structured logs, tracing spans, and metrics where they aid debugging or operational behavior. Follow existing instrumentation patterns, keep secrets and sensitive data out of logs, and prefer generated wrappers over hand-written span boilerplate.

## Security

15. Validate all external input at trust boundaries, keep secrets out of logs and errors, reuse the repository’s TLS, authentication, authorization, and secret-handling mechanisms, and follow the existing security review pattern for new external interfaces.

## API compatibility

16. Preserve compatibility with released API versions. Unreleased work on `main` may still change. Once an API is released, keep it backward compatible unless explicitly versioned; breaking changes require a new version, deprecation notice, and migration path.

## Transactions

17. Keep transactions inside the store layer when possible. Document ownership when a service must coordinate a transaction, and always ensure rollback on error.

## Testing depth

18. Add or extend tests for changed behavior, keep unit tests isolated, use integration and e2e tests for external boundaries, and run race-enabled tests for concurrent code.

## API standards

19. Follow Kubernetes API conventions for Flight Control APIs.
20. Prefer `v1beta1` for new core API work.

## Internal architecture standards

21. Follow the runtime ownership rules: legacy/shared code stays in place; component-owned code goes under its component namespace; stores never depend on services.
22. Service sub-packages use the established file shape: `service.go`, `handler.go`, `docs.go`, adjacent tests, and generated mock and tracing files. Use the pinned generators.

## Agent standards

23. Minimize dependencies and prefer serial operations unless concurrency is required.
24. Route all disk access through fileio.
25. Access specs only through the spec manager.
26. Use `errors.WithElement()` when an identifier would help status messages.
27. Use gomock with `defer ctrl.Finish()` and inline `setupMocks`.

## Testing standards

28. Extend the existing e2e harness and infrastructure. Do not call raw `kubectl` or the raw Kubernetes client outside `test/e2e/infra/k8s/`.

## Deployment standards

29. Generate Helm metadata from `.gotmpl` sources. Do not hand-edit generated chart files.
30. Keep quadlet unit ordering and configuration in sync with deployment scripts, preserving idempotency and error handling.

## Review scope

31. Treat review-scope growth as a judgment call, not a counting exercise. Before expanding a fix, note whether it adds new files, new test files, or crosses subsystems, and explain why the existing files are insufficient. Pause and ask when the change is broader than the underlying finding.
32. Classify each review finding as correctness, coverage, or style. Correctness findings may expand the diff; coverage and style findings should reuse existing files unless they test a new boundary.
33. Prefer extending an existing test file over creating a new one. Create a new test file only for a new package, a new integration boundary, or a distinct external contract.
34. Report generated files separately from hand-written files so the diff’s apparent size is not misleading.
35. When a change crosses more than three subsystems, add a one-paragraph impact note naming the affected areas and why the feature requires them. If the impact is review-driven rather than feature-required, ask before proceeding.

## Verification

Run the checks that apply to the area you touched. At minimum, use `make lint` and the relevant test target.
