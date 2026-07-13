#!/usr/bin/env bash

set -euo pipefail

REPOSITORY_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PUBLISHER="$REPOSITORY_ROOT/scripts/publish-board.sh"
TEMPORARY_DIRECTORY=$(mktemp -d)
trap 'rm -rf "$TEMPORARY_DIRECTORY"' EXIT

REMOTE="$TEMPORARY_DIRECTORY/public-boards.git"
SEED="$TEMPORARY_DIRECTORY/seed"
PUBLISHER_ONE="$TEMPORARY_DIRECTORY/publisher-one"
PUBLISHER_TWO="$TEMPORARY_DIRECTORY/publisher-two"
FINAL_CLONE="$TEMPORARY_DIRECTORY/final"
ASR_SOURCE="$TEMPORARY_DIRECTORY/asr.html"
SKUD_SOURCE="$TEMPORARY_DIRECTORY/skud.html"
UNSAFE_SOURCE="$TEMPORARY_DIRECTORY/unsafe.html"

git init --bare --initial-branch=main "$REMOTE" >/dev/null
git clone "$REMOTE" "$SEED" >/dev/null 2>&1
git -C "$SEED" config user.name "Test Seeder"
git -C "$SEED" config user.email "test-seeder@example.invalid"
printf '%s\n' '# Public boards' >"$SEED/README.md"
git -C "$SEED" add README.md
git -C "$SEED" commit -m "chore: seed public boards" >/dev/null
git -C "$SEED" push origin main >/dev/null 2>&1

git clone "$REMOTE" "$PUBLISHER_ONE" >/dev/null 2>&1
git clone "$REMOTE" "$PUBLISHER_TWO" >/dev/null 2>&1

printf '%s\n' \
  '<!doctype html><html><head><title>ASR Board</title></head>' \
  '<body>safe ASR content</body></html>' >"$ASR_SOURCE"
printf '%s\n' \
  '<!doctype html><html><head><title>SKUD Board</title></head>' \
  '<body>safe SKUD content</body></html>' >"$SKUD_SOURCE"
printf '%s\n' \
  '<!doctype html><html><head><title>Unsafe Board</title></head>' \
  '<body>password = hunter2</body></html>' >"$UNSAFE_SOURCE"

(
  cd "$PUBLISHER_ONE"
  "$PUBLISHER" \
    "$ASR_SOURCE" \
    "asr/index.html" \
    "example/asr" \
    "asr-sha"
)

# Publisher two remains on the seed commit while publisher one advances main.
(
  cd "$PUBLISHER_TWO"
  "$PUBLISHER" \
    "$SKUD_SOURCE" \
    "skud/index.html" \
    "example/skud" \
    "skud-sha"
)

git clone "$REMOTE" "$FINAL_CLONE" >/dev/null 2>&1
cmp -s "$ASR_SOURCE" "$FINAL_CLONE/asr/index.html"
cmp -s "$SKUD_SOURCE" "$FINAL_CLONE/skud/index.html"

ASR_COMMIT=$(git -C "$FINAL_CLONE" log -1 --format='%H' -- asr/index.html)
SKUD_COMMIT=$(git -C "$FINAL_CLONE" log -1 --format='%H' -- skud/index.html)
test "$(git -C "$FINAL_CLONE" show -s --format='%an' "$ASR_COMMIT")" = "github-actions[bot]"
test "$(git -C "$FINAL_CLONE" show -s --format='%an' "$SKUD_COMMIT")" = "github-actions[bot]"
test "$(git -C "$FINAL_CLONE" show -s --format='%s' "$ASR_COMMIT")" = \
  "chore(boards): publish asr/index.html from example/asr@asr-sha"
test "$(git -C "$FINAL_CLONE" show -s --format='%s' "$SKUD_COMMIT")" = \
  "chore(boards): publish skud/index.html from example/skud@skud-sha"

REMOTE_BEFORE_UNSAFE=$(git --git-dir="$REMOTE" rev-parse refs/heads/main)
if (
  cd "$PUBLISHER_TWO"
  "$PUBLISHER" \
    "$UNSAFE_SOURCE" \
    "asr/index.html" \
    "example/asr" \
    "unsafe-sha"
); then
  echo "unsafe publication unexpectedly succeeded" >&2
  exit 1
fi
REMOTE_AFTER_UNSAFE=$(git --git-dir="$REMOTE" rev-parse refs/heads/main)
test "$REMOTE_AFTER_UNSAFE" = "$REMOTE_BEFORE_UNSAFE"

echo "publish integration: pass"
