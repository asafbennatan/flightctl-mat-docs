#!/usr/bin/env bash
set -euo pipefail

TEST_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
OVERLAY_ROOT=$TEST_ROOT
TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/flightctl-overlay-tests.XXXXXX")
: > "$TEST_TMP/gitconfig"
export GIT_CONFIG_GLOBAL="$TEST_TMP/gitconfig"
export GIT_CONFIG_NOSYSTEM=1

cleanup() {
  if [[ "${KEEP_TEST_TMP:-0}" == 1 ]]; then
    printf 'Test fixtures retained at %s\n' "$TEST_TMP" >&2
  else
    rm -rf -- "$TEST_TMP"
  fi
}
trap cleanup EXIT

fail() {
  printf 'not ok - %s\n' "$*" >&2
  exit 1
}

pass() {
  printf 'ok - %s\n' "$*"
}

new_repo() {
  local repo=$1
  mkdir -p "$repo"
  git -C "$repo" init -q --initial-branch=main
  git -C "$repo" config user.name 'Overlay Test'
  git -C "$repo" config user.email 'overlay-test@example.invalid'
  git -C "$repo" config commit.gpgsign false
}

commit_all() {
  local repo=$1
  local message=$2
  git -C "$repo" add -A
  git -C "$repo" commit -q -m "$message"
}

assert_contains() {
  local expected=$1
  local file=$2
  grep -Fq -- "$expected" "$file" || fail "expected '$file' to contain '$expected'"
}
