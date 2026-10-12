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
  for pattern in /.scratch /docs/adr /GLOSSARY.md; do
    grep -Fqx "$pattern" "$exclude_file" || fail "installer did not add '$pattern' to the local exclude file"
  done

  for overlay_path in .scratch docs/adr GLOSSARY.md; do
    [[ -L "$checkout/$overlay_path" ]] || fail "installer did not link $overlay_path"
    [[ $(readlink "$checkout/$overlay_path") == "$OVERLAY_ROOT/$overlay_path" ]] ||
      fail "installer linked $overlay_path to the wrong overlay path"
  done
  if ! git -C "$checkout" check-ignore -q --no-index -- .scratch; then
    git -C "$checkout" check-ignore -v --no-index -- .scratch >&2 || true
    fail 'the local exclude rules do not ignore the linked overlay'
  fi
  pass 'installer sets local ignores, symlinks, and managed hooks'

  if ! "$OVERLAY_ROOT/scripts/install-flightctl-overlay" "$checkout" > "$install_output" 2>&1; then
    cat "$install_output" >&2
    fail 'reinstall failed'
  fi
  for pattern in /.scratch /docs/adr /GLOSSARY.md; do
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
  if grep -Eq '^(\.scratch/|docs/adr/|GLOSSARY\.md$)' <<< "$remote_paths"; then
    fail 'the temporary upstream received an overlay path'
  fi
  pass 'existing commit and push hooks run while code-only changes reach upstream'

  worktree="$TEST_TMP/flightctl linked worktree"
  OVERLAY_TEST_MARKER="$marker" git -C "$checkout" worktree add -q -b overlay/integration "$worktree" main
  for overlay_path in .scratch docs/adr GLOSSARY.md; do
    [[ -L "$worktree/$overlay_path" ]] || fail "new linked worktree did not receive $overlay_path"
    [[ $(readlink "$worktree/$overlay_path") == "$OVERLAY_ROOT/$overlay_path" ]] ||
      fail "new worktree linked $overlay_path to the wrong overlay path"
  done
  assert_contains post-checkout "$marker"
  [[ $(grep -Fxc post-checkout "$marker") -eq 1 ]] || fail 'post-checkout hook chaining ran more than once'
  [[ -z $(git -C "$worktree" status --porcelain) ]] || fail 'overlay links made the new worktree appear dirty'
  pass 'new linked worktrees receive the overlay through post-checkout'
}

test_installation_and_linked_worktree_propagation
