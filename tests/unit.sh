#!/usr/bin/env bash
set -euo pipefail

source "$(dirname -- "${BASH_SOURCE[0]}")/test-lib.sh"

test_pre_commit_allows_code_changes() {
  local repo="$TEST_TMP/pre-commit-code"
  new_repo "$repo"
  mkdir -p "$repo/internal"
  printf 'package internal\n' > "$repo/internal/example.go"
  git -C "$repo" add -- internal/example.go

  (cd -- "$repo" && "$OVERLAY_ROOT/scripts/guard-pre-commit") ||
    fail 'pre-commit guard rejected an ordinary source change'
  pass 'pre-commit allows ordinary source changes'
}

test_pre_commit_blocks_overlay_changes() {
  local path slug repo output
  for path in .scratch/notes.md docs/adr/0001.md GLOSSARY.md docs/agents docs/agents/issue-tracker.md; do
    slug=${path//\//_}
    repo="$TEST_TMP/pre-commit-$slug"
    output="$TEST_TMP/pre-commit-$slug.out"
    new_repo "$repo"
    mkdir -p "$(dirname -- "$repo/$path")"
    printf 'local material\n' > "$repo/$path"
    git -C "$repo" add -f -- "$path"

    if (cd -- "$repo" && "$OVERLAY_ROOT/scripts/guard-pre-commit") > "$output" 2>&1; then
      fail "pre-commit guard accepted staged overlay path '$path'"
    fi
    assert_contains 'Commit blocked:' "$output"
    pass "pre-commit blocks staged $path"
  done
}

test_pre_push_allows_code_changes() {
  local repo="$TEST_TMP/pre-push-code"
  local input="$TEST_TMP/pre-push-code.input"
  new_repo "$repo"
  printf 'base\n' > "$repo/README.md"
  commit_all "$repo" 'base commit'
  local base_sha
  base_sha=$(git -C "$repo" rev-parse HEAD)

  mkdir -p "$repo/internal"
  printf 'source\n' > "$repo/internal/example.go"
  commit_all "$repo" 'code change'
  local local_sha
  local_sha=$(git -C "$repo" rev-parse HEAD)
  printf 'refs/heads/main %s refs/heads/main %s\n' "$local_sha" "$base_sha" > "$input"

  (cd -- "$repo" && "$OVERLAY_ROOT/scripts/guard-pre-push" origin < "$input") ||
    fail 'pre-push guard rejected an ordinary source change'
  pass 'pre-push allows ordinary source changes'
}

test_pre_push_blocks_overlay_changes() {
  local path slug repo output input base_sha local_sha
  for path in .scratch/notes.md docs/adr/0001.md GLOSSARY.md docs/agents docs/agents/issue-tracker.md; do
    slug=${path//\//_}
    repo="$TEST_TMP/pre-push-$slug"
    output="$TEST_TMP/pre-push-$slug.out"
    input="$TEST_TMP/pre-push-$slug.input"
    new_repo "$repo"
    printf 'base\n' > "$repo/README.md"
    commit_all "$repo" 'base commit'
    base_sha=$(git -C "$repo" rev-parse HEAD)

    mkdir -p "$(dirname -- "$repo/$path")"
    printf 'local material\n' > "$repo/$path"
    git -C "$repo" add -f -- "$path"
    git -C "$repo" commit -q -m 'local material change'
    local_sha=$(git -C "$repo" rev-parse HEAD)
    printf 'refs/heads/main %s refs/heads/main %s\n' "$local_sha" "$base_sha" > "$input"

    if (cd -- "$repo" && "$OVERLAY_ROOT/scripts/guard-pre-push" origin < "$input") > "$output" 2>&1; then
      fail "pre-push guard accepted an outgoing commit containing '$path'"
    fi
    assert_contains 'Push blocked to origin:' "$output"
    assert_contains "$path" "$output"
    pass "pre-push blocks outgoing $path"
  done
}

test_pre_commit_allows_code_changes
test_pre_commit_blocks_overlay_changes
test_pre_push_allows_code_changes
test_pre_push_blocks_overlay_changes
