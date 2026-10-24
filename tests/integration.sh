#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/test-lib.sh"

create_marker_hook() {
  local hook_path=$1
  cat > "$hook_path" <<'HOOK'
#!/bin/sh
hook_name=${0##*/}
printf '%s\n' "$hook_name" >> "$OVERLAY_TEST_MARKER"
if [ "$hook_name" = pre-push ]; then
  while IFS= read -r line; do
    printf 'stdin:%s\n' "$line" >> "$OVERLAY_TEST_MARKER"
  done
fi
HOOK
  chmod 755 "$hook_path"
}

test_installation_and_linked_worktree_propagation() {
  local seed="$TEST_TMP/seed"
  local remote="$TEST_TMP/flightctl-upstream.git"
  local checkout="$TEST_TMP/flightctl checkout"
  local custom_hooks="$TEST_TMP/custom hooks"
  local marker="$TEST_TMP/hook events.log"
  local install_output="$TEST_TMP/install.out"
  local common_dir state_dir hooks_dir exclude_file pattern worktree remote_paths

  new_repo "$seed"
  printf 'Flight Control fixture\n' > "$seed/README.md"
  commit_all "$seed" 'initial fixture'
  git clone -q --bare "$seed" "$remote"
  git clone -q "$remote" "$checkout"
  git -C "$checkout" config user.name 'Overlay Test'
  git -C "$checkout" config user.email 'overlay-test@example.invalid'
  git -C "$checkout" config commit.gpgsign false

  mkdir -p "$checkout/docs/agents"
  ln -s "$OVERLAY_ROOT/docs/agents/domain.md" "$checkout/docs/agents/domain.md"

  mkdir -p "$custom_hooks"
  for hook_name in post-checkout pre-commit pre-push; do
    create_marker_hook "$custom_hooks/$hook_name"
  done
  git -C "$checkout" config --local core.hooksPath "$custom_hooks"
  : > "$marker"

  if ! "$OVERLAY_ROOT/scripts/install-flightctl-overlay" "$checkout" > "$install_output" 2>&1; then
    cat "$install_output" >&2
    fail 'installer failed for a clean temporary clone'
  fi

  common_dir=$(git -C "$checkout" rev-parse --git-common-dir)
  if [[ "$common_dir" != /* ]]; then
    common_dir="$checkout/$common_dir"
  fi
  common_dir=$(cd -- "$common_dir" && pwd -P)
  state_dir="$common_dir/flightctl-mat-docs-overlay"
  hooks_dir="$state_dir/hooks"
  [[ $(git -C "$checkout" config --local --get core.hooksPath) == "$hooks_dir" ]] ||
    fail 'installer did not set the clone-local hooks path'
  [[ $(git -C "$checkout" config --local --get flightctl-mat-docs.overlayRoot) == "$OVERLAY_ROOT" ]] ||
    fail 'installer did not store the overlay root in local Git config'
  [[ -x "$state_dir/prior-hooks/pre-commit" ]] || fail 'installer did not preserve the existing pre-commit hook'
  [[ -x "$state_dir/prior-hooks/pre-push" ]] || fail 'installer did not preserve the existing pre-push hook'
  [[ -x "$state_dir/prior-hooks/post-checkout" ]] || fail 'installer did not preserve the existing post-checkout hook'

  exclude_file=$(git -C "$checkout" rev-parse --git-path info/exclude)
  if [[ "$exclude_file" != /* ]]; then
    exclude_file="$checkout/$exclude_file"
  fi
  for pattern in /.scratch /docs/adr /GLOSSARY-MAP.md /glossaries /docs/agents; do
    grep -Fqx "$pattern" "$exclude_file" || fail "installer did not add '$pattern' to the local exclude file"
  done

  for overlay_path in .scratch docs/adr GLOSSARY-MAP.md glossaries docs/agents; do
    [[ -L "$checkout/$overlay_path" ]] || fail "installer did not link $overlay_path"
    [[ $(readlink "$checkout/$overlay_path") == "$OVERLAY_ROOT/$overlay_path" ]] ||
      fail "installer linked $overlay_path to the wrong overlay path"
  done
  [[ -f "$checkout/docs/agents/issue-tracker.md" ]] ||
    fail 'installer did not expose the shared issue-tracker guidance'
  [[ -f "$checkout/docs/agents/triage-labels.md" ]] ||
    fail 'installer did not expose the shared triage labels'
  [[ -f "$OVERLAY_ROOT/docs/agents/domain.md" ]] ||
    fail 'installer removed the shared domain guide while migrating its old link'
  if ! git -C "$checkout" check-ignore -q --no-index -- .scratch; then
    git -C "$checkout" check-ignore -v --no-index -- .scratch >&2 || true
    fail 'the local exclude rules do not ignore the linked overlay'
  fi
  pass 'installer sets local ignores, symlinks, and managed hooks'

  if ! "$OVERLAY_ROOT/scripts/install-flightctl-overlay" "$checkout" > "$install_output" 2>&1; then
    cat "$install_output" >&2
    fail 'reinstall failed'
  fi
  for pattern in /.scratch /docs/adr /GLOSSARY-MAP.md /glossaries /docs/agents; do
    [[ $(grep -Fxc "$pattern" "$exclude_file") -eq 1 ]] || fail "reinstall duplicated '$pattern' in the exclude file"
  done
  pass 'reinstall is idempotent for local excludes and hooks'

  printf 'ordinary code change\n' > "$checkout/source.txt"
  git -C "$checkout" add -- source.txt
  OVERLAY_TEST_MARKER="$marker" git -C "$checkout" commit -q -m 'ordinary code change'
  assert_contains pre-commit "$marker"
  [[ $(grep -Fxc pre-commit "$marker") -eq 1 ]] || fail 'pre-commit hook chaining ran more than once'

  OVERLAY_TEST_MARKER="$marker" git -C "$checkout" push -q origin main
  assert_contains pre-push "$marker"
  assert_contains 'stdin:refs/heads/main ' "$marker"
  [[ $(grep -Fxc pre-push "$marker") -eq 1 ]] || fail 'pre-push hook chaining ran more than once'
  remote_paths=$(git --git-dir="$remote" ls-tree -r --name-only main)
  if grep -Eq '^(\.scratch/|docs/adr/|GLOSSARY\.md$|GLOSSARY-MAP\.md$|glossaries($|/)|docs/agents($|/))' <<< "$remote_paths"; then
    fail 'the temporary upstream received an overlay path'
  fi
  pass 'existing commit and push hooks run while code-only changes reach upstream'

  worktree="$TEST_TMP/flightctl linked worktree"
  OVERLAY_TEST_MARKER="$marker" git -C "$checkout" worktree add -q -b overlay/integration "$worktree" main
  for overlay_path in .scratch docs/adr GLOSSARY-MAP.md glossaries docs/agents; do
    [[ -L "$worktree/$overlay_path" ]] || fail "new linked worktree did not receive $overlay_path"
    [[ $(readlink "$worktree/$overlay_path") == "$OVERLAY_ROOT/$overlay_path" ]] ||
      fail "new worktree linked $overlay_path to the wrong overlay path"
  done
  [[ -f "$worktree/docs/agents/coding-standards.md" ]] ||
    fail 'new linked worktree did not receive the shared coding standards'
  assert_contains post-checkout "$marker"
  [[ $(grep -Fxc post-checkout "$marker") -eq 1 ]] || fail 'post-checkout hook chaining ran more than once'
  [[ -z $(git -C "$worktree" status --porcelain) ]] || fail 'overlay links made the new worktree appear dirty'
  pass 'new linked worktrees receive the overlay through post-checkout'

  if ! "$OVERLAY_ROOT/scripts/uninstall-flightctl-overlay" "$checkout" > "$install_output" 2>&1; then
    cat "$install_output" >&2
    fail 'uninstall failed after the integration checks'
  fi
  for path in "$checkout" "$worktree"; do
    [[ ! -e "$path/GLOSSARY-MAP.md" && ! -L "$path/GLOSSARY-MAP.md" ]] ||
      fail "uninstall left the glossary map link in $path"
    [[ ! -e "$path/glossaries" && ! -L "$path/glossaries" ]] ||
      fail "uninstall left the glossaries overlay link in $path"
    [[ ! -e "$path/docs/agents" && ! -L "$path/docs/agents" ]] ||
      fail "uninstall left the docs/agents overlay link in $path"
  done
  if grep -Fqx '/glossaries' "$exclude_file"; then
    fail 'uninstall left the glossaries local exclude in place'
  fi
  if grep -Fqx '/docs/agents' "$exclude_file"; then
    fail 'uninstall left the docs/agents local exclude in place'
  fi
  pass 'uninstall removes docs/agents links and its local exclude'
}

test_install_preserves_local_agent_docs_on_migration_conflict() {
  local seed="$TEST_TMP/agent-docs-seed"
  local remote="$TEST_TMP/agent-docs-upstream.git"
  local checkout="$TEST_TMP/agent-docs-checkout"
  local install_output="$TEST_TMP/agent-docs-install.out"

  new_repo "$seed"
  printf 'Flight Control fixture\n' > "$seed/README.md"
  commit_all "$seed" 'initial fixture'
  git clone -q --bare "$seed" "$remote"
  git clone -q "$remote" "$checkout"

  mkdir -p "$checkout/docs/agents"
  ln -s "$OVERLAY_ROOT/docs/agents/domain.md" "$checkout/docs/agents/domain.md"
  printf 'local agent instructions\n' > "$checkout/docs/agents/local.md"

  if "$OVERLAY_ROOT/scripts/install-flightctl-overlay" "$checkout" > "$install_output" 2>&1; then
    fail 'installer replaced local docs/agents content during migration'
  fi
  assert_contains 'Leaving untracked local path in place:' "$install_output"
  [[ -L "$checkout/docs/agents/domain.md" ]] ||
    fail 'installer removed the legacy domain link next to local docs'
  [[ $(cat "$checkout/docs/agents/local.md") == 'local agent instructions' ]] ||
    fail 'installer changed the local docs/agents file'
  [[ -f "$OVERLAY_ROOT/docs/agents/domain.md" ]] ||
    fail 'installer removed the shared domain guide during conflict handling'
  pass 'installer preserves local docs/agents files when migration conflicts'
}

test_sync_migrates_legacy_root_glossary_link() {
  local repo="$TEST_TMP/legacy-glossary-checkout"
  local state_dir="$TEST_TMP/legacy-glossary-state"
  local output="$TEST_TMP/legacy-glossary-sync.out"

  new_repo "$repo"
  git -C "$repo" config --local flightctl-mat-docs.overlayRoot "$OVERLAY_ROOT"
  git -C "$repo" config --local --path flightctl-mat-docs.stateDir "$state_dir"
  mkdir -p "$state_dir"
  ln -s "$OVERLAY_ROOT/GLOSSARY.md" "$repo/GLOSSARY.md"

  if ! "$OVERLAY_ROOT/scripts/flightctl-mat-docs-sync" "$repo" > "$output" 2>&1; then
    cat "$output" >&2
    fail 'sync failed while migrating the legacy glossary link'
  fi
  [[ ! -e "$repo/GLOSSARY.md" && ! -L "$repo/GLOSSARY.md" ]] ||
    fail 'sync left the legacy root glossary link in place'
  [[ -L "$repo/GLOSSARY-MAP.md" ]] || fail 'sync did not link the glossary map'
  [[ $(readlink "$repo/GLOSSARY-MAP.md") == "$OVERLAY_ROOT/GLOSSARY-MAP.md" ]] ||
    fail 'sync linked the glossary map to the wrong target'
  [[ -L "$repo/glossaries" ]] || fail 'sync did not link the glossary contexts'
  [[ $(readlink "$repo/glossaries") == "$OVERLAY_ROOT/glossaries" ]] ||
    fail 'sync linked the glossary contexts to the wrong target'
  pass 'sync migrates the legacy root glossary link to the mapped contexts'
}

test_installation_and_linked_worktree_propagation
test_install_preserves_local_agent_docs_on_migration_conflict
test_sync_migrates_legacy_root_glossary_link
