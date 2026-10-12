# Flight Control local materials overlay

This repository holds personal Flight Control materials that should stay out of
flightctl/flightctl, including .scratch/, docs/adr/, and GLOSSARY.md. Keep this
clone outside every Flight Control clone.

## Install on each computer

Clone or update this repository, then install it once for each independent
Flight Control clone:

    mkdir -p ~/src
    git clone https://github.com/asafbennatan/flightctl-mat-docs.git ~/src/flightctl-mat-docs
    ~/src/flightctl-mat-docs/scripts/install-flightctl-overlay ~/src/flightctl

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
.git/info/exclude, then links the three overlay paths into its worktrees.
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

## Edit and commit overlay material

The linked paths are the files in this repository. Commit and push them from
this repository:

    git -C ~/src/flightctl-mat-docs add .scratch docs/adr GLOSSARY.md
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
