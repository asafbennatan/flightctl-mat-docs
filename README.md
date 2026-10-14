# Flight Control local materials overlay

This repository holds personal Flight Control materials that should stay out of
flightctl/flightctl, including .scratch/, docs/adr/, GLOSSARY-MAP.md, the
glossaries/ contexts, and docs/agents/ configuration for the engineering
skills. Keep this clone outside every Flight Control clone.

## Install on each computer

Clone or update this repository, then install it once for each independent
Flight Control clone:

    mkdir -p ~/src
    git clone https://github.com/asafbennatan/flightctl-mat-docs.git ~/src/flightctl-mat-docs
    ~/src/flightctl-mat-docs/install.sh ~/src/flightctl

For an existing docs checkout, update it with
git -C /path/to/flightctl-mat-docs pull --ff-only and use its path below.

If either repository is already cloned, use its existing path. The installer
accepts a Flight Control checkout or one of its worktrees; linked worktrees
share the same Git metadata, so installing once covers that clone's current
and future worktrees. Repeat the install for a separate Flight Control clone
or on another computer. The installer links the checkout you pass. To add the
overlay to a different already-existing worktree, run the sync command below
for that worktree.

The installer stores the docs checkout path and hook state in the Flight
Control clone's local Git metadata. It adds the overlay paths to that clone's
.git/info/exclude, then links the shared material paths into its worktrees.
These settings do not go into Flight Control commits.

After installation, ordinary git worktree add, git switch, and git checkout
operations link the overlay through a local post-checkout hook. If a worktree
was created with --no-checkout, run the sync script after checking out its
branch:

    ~/src/flightctl-mat-docs/scripts/flightctl-mat-docs-sync /path/to/worktree

If you move this checkout, rerun the installer so local Git metadata points to
its new location.

To refresh the overlay on a computer after its docs checkout has new commits,
pull that checkout. The links show its updated files immediately; reinstall
only if the docs checkout moved.

To remove the overlay from a Flight Control clone, run:

    ~/src/flightctl-mat-docs/uninstall.sh ~/src/flightctl

The uninstaller removes overlay links from its existing worktrees, restores
any local files saved during installation, and restores the previous hooks
configuration. Run it from the same docs checkout used to install the overlay.

## Edit and commit overlay material

The linked paths are the files in this repository. Commit and push them from
this repository:

    git -C ~/src/flightctl-mat-docs add .scratch docs/adr GLOSSARY-MAP.md glossaries docs/agents
    git -C ~/src/flightctl-mat-docs commit -m "Update local Flight Control materials"
    git -C ~/src/flightctl-mat-docs push

Flight Control's local hooks block commits that stage these paths and pushes
whose outgoing commits contain them. The push check uses refs for the selected
push remote; a copy of a commit on an unrelated remote does not make it safe to
send elsewhere. Existing branches with overlay files in their history must
have that history cleaned before they can be pushed.

Local Git hooks are a guard for ordinary workflows. A user can bypass or
remove them, so a strict server-enforced guarantee also requires an upstream
server-side rule that rejects these paths.

## Test the setup

Run the shell tests with Bash and Git installed:

    tests/run.sh

GitHub Actions runs the same command on pull requests and pushes to `main`.

The integration test creates disposable Git repositories and a local bare
remote, then removes them when it exits.
