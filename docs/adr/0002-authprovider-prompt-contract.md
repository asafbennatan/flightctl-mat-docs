---
status: accepted
---

# Distinguish absent and empty authorization prompts

The agreed AuthProvider contract adds optional `prompt` fields to both OIDC and
OAuth2 provider configurations.
It uses `login` when `prompt` is omitted or JSON `null` and omits the authorization
request parameter when `prompt` is explicitly empty.
This distinction provides a default while allowing operators to delegate prompt
behavior to their identity provider.

Accept a string that can contain multiple prompt values and provider-specific
extensions, rather than a single-value enum.
This represents the space-separated values and extensions described by
[OIDC Core](https://openid.net/specs/openid-connect-core-1_0.html#AuthRequest).

Public authentication configuration resolves an absent prompt to `login`,
including for existing providers and after PATCH removes the field.
An explicitly empty prompt remains empty.
This requires no database backfill; AuthProvider CRUD responses can retain an
omitted field, and schema defaults can materialize `login` on writes.

Validation rejects `none` combined with another prompt value while accepting
provider-specific values and preserving accepted strings as supplied.
Nonempty strings must contain printable ASCII values separated by ordinary
spaces; tabs, newlines, non-ASCII characters, and whitespace-only strings are
invalid.
Leading, trailing, and repeated spaces are accepted without rewriting.
Duplicate values are accepted, including `none none`; `none` is matched
case-sensitively and cannot accompany a different value.

## API delivery scope

Provider change detection must include `prompt` for both OIDC and OAuth2 so
prompt-only edits refresh the cached public authentication configuration.
The work covers API schemas, generated types, validation, public configuration,
documentation, and tests.
Changes to UI forms and authorization request construction are outside this scope.

Validation should cover defaults for existing providers, explicit empty and null
values, string validation, CRUD and PATCH behavior, and public configuration
refresh after a prompt-only edit.
