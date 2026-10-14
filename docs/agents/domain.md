# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Preserve shared documents

In Flight Control worktrees, `GLOSSARY-MAP.md`, `glossaries/`, `docs/adr/`,
`.scratch/`, and the `docs/agents/` directory are shared through symlinks into
`flightctl-mat-docs`. Git ignores these paths in the Flight Control checkout
so they stay in the materials repository. An ignored path can still be an
existing shared document.

Before writing to one of these paths:

- Inspect the destination and its parent directories for symlinks. Check with
  `test -L` and `readlink`; a broken symlink may not pass `test -e`.
- Read the current contents and make a focused edit through the symlink,
  preserving the link, target, and unrelated content.
- Use setup templates only for genuinely missing files. Update this generated
  domain guide in place and preserve its additional instructions.
- If a link is broken or its target is unavailable, report the problem and
  restore the overlay before writing. Do not create a local replacement.
- Keep shared edits in `flightctl-mat-docs` and commit them from that repo.

## Before exploring, read these

- **`GLOSSARY-MAP.md`** at the repo root: it points at one `GLOSSARY.md` per context. Read each one relevant to the topic.
- **`docs/adr/`**: read ADRs that touch the area you're working in. In multi-context repos, also check context-scoped ADR directories.

If any of these files don't exist, **proceed silently**. Don't flag their absence; don't suggest creating them upfront. The `/domain-modeling` skill creates them lazily when terms or decisions actually get resolved.

## File structure

Single-context repo (most repos):

```
/
├── GLOSSARY.md
├── docs/adr/
│   ├── 0001-event-sourced-orders.md
│   └── 0002-postgres-for-write-model.md
└── src/
```

Multi-context repo (presence of `GLOSSARY-MAP.md` at the root):

```
/
├── GLOSSARY-MAP.md
├── docs/adr/                          ← system-wide decisions
└── glossaries/
    ├── ordering/GLOSSARY.md
    └── billing/GLOSSARY.md
```

## Use the glossary's vocabulary

When your output names a domain concept, use the term as defined in the relevant context glossary. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in a context glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-0007 (event-sourced orders), but worth reopening because…_
