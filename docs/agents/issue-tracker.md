# Issue tracker: Local Markdown

Issues and specs for this repo live as Markdown files in `.scratch/`.

## Conventions

- One feature per directory: `.scratch/<feature-slug>/`
- The feature spec is `.scratch/<feature-slug>/spec.md`
- Implementation tickets are individual files in `.scratch/<feature-slug>/issues/`, numbered from `01` as `<NN>-<slug>.md`
- When a triage status is needed, put a `Status:` line near the top of the issue file; use the roles in `triage-labels.md`
- Append comments and conversation history under `## Comments`

## When a skill says “publish to the issue tracker”

Create the feature directory if needed. Save each implementation ticket as a separate, next-numbered file at `.scratch/<feature-slug>/issues/<NN>-<slug>.md`. Save feature specs as `spec.md`.

## When a skill says “fetch the relevant ticket”

Read the file at the referenced path. The user will normally provide the path or issue number.

## Wayfinding operations

Used by `/wayfinder`. A map has one child file per ticket.

- **Map**: `.scratch/<effort>/map.md` (Notes / Decisions-so-far / Fog)
- **Child ticket**: `.scratch/<effort>/issues/NN-<slug>.md`; a `Type:` line records `research`, `prototype`, `grilling`, or `task`; a `Status:` line records `claimed` or `resolved`
- **Blocking**: `Blocked by: NN, NN` near the top; a ticket is unblocked when each listed file is `resolved`
- **Frontier**: scan the issues directory for open, unblocked, unclaimed files; first by number wins
- **Claim**: set `Status: claimed` before work
- **Resolve**: append the answer under `## Answer`, set `Status: resolved`, then add a context pointer to the map’s Decisions-so-far

When a task explicitly requests Jira, follow the repo instructions and use
`acli` for Jira access. The default destination for skills that publish tickets
is `.scratch/`.
