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
REVIEW_PUBLISHER_ONE="$TEMPORARY_DIRECTORY/review-publisher-one"
REVIEW_PUBLISHER_TWO="$TEMPORARY_DIRECTORY/review-publisher-two"
FINAL_CLONE="$TEMPORARY_DIRECTORY/final"
REVIEW_CLONE="$TEMPORARY_DIRECTORY/review"
ASR_SOURCE="$TEMPORARY_DIRECTORY/asr.html"
SKUD_SOURCE="$TEMPORARY_DIRECTORY/skud.html"
CALL_AI_SOURCE="$TEMPORARY_DIRECTORY/call-ai.html"
CLIENT_SKUD_SOURCE="$TEMPORARY_DIRECTORY/client-skud.html"
UNSAFE_SOURCE="$TEMPORARY_DIRECTORY/unsafe.html"
REVIEW_REF="chore/manual-board-sync"

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
git clone "$REMOTE" "$REVIEW_PUBLISHER_ONE" >/dev/null 2>&1
git clone "$REMOTE" "$REVIEW_PUBLISHER_TWO" >/dev/null 2>&1

printf '%s\n' \
  '<!doctype html><html><head><title>ASR Board</title></head>' \
  '<body>safe ASR content</body></html>' >"$ASR_SOURCE"
printf '%s\n' \
  '<!doctype html><html><head><title>SKUD Board</title></head>' \
  '<body>safe SKUD content</body></html>' >"$SKUD_SOURCE"
printf '%s\n' \
  '<!doctype html><html><head><title>Call AI Board</title></head>' \
  '<body>safe Call AI content</body></html>' >"$CALL_AI_SOURCE"
printf '%s\n' \
  '<!doctype html><html><head><title>Client SKUD Board</title></head>' \
  '<body>safe Client SKUD content</body></html>' >"$CLIENT_SKUD_SOURCE"
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

MAIN_BEFORE_REVIEW=$(git --git-dir="$REMOTE" rev-parse refs/heads/main)
(
  cd "$REVIEW_PUBLISHER_ONE"
  PUBLISH_TARGET_REF="$REVIEW_REF" "$PUBLISHER" \
    "$CALL_AI_SOURCE" \
    "call-ai/index.html" \
    "example/call-ai" \
    "call-ai-sha"
)

# A second clean publisher must preserve the first review-branch publication.
(
  cd "$REVIEW_PUBLISHER_TWO"
  PUBLISH_TARGET_REF="$REVIEW_REF" "$PUBLISHER" \
    "$CLIENT_SKUD_SOURCE" \
    "client-skud/index.html" \
    "example/client-skud" \
    "client-skud-sha"
)

MAIN_AFTER_REVIEW=$(git --git-dir="$REMOTE" rev-parse refs/heads/main)
test "$MAIN_AFTER_REVIEW" = "$MAIN_BEFORE_REVIEW"
git clone --branch "$REVIEW_REF" "$REMOTE" "$REVIEW_CLONE" >/dev/null 2>&1
cmp -s "$CALL_AI_SOURCE" "$REVIEW_CLONE/call-ai/index.html"
cmp -s "$CLIENT_SKUD_SOURCE" "$REVIEW_CLONE/client-skud/index.html"

REMOTE_BEFORE_INVALID_REF=$(git --git-dir="$REMOTE" rev-parse refs/heads/main)
if (
  cd "$PUBLISHER_TWO"
  PUBLISH_TARGET_REF="invalid ref" "$PUBLISHER" \
    "$ASR_SOURCE" \
    "asr/index.html" \
    "example/asr" \
    "invalid-ref-sha"
); then
  echo "publication with an invalid target ref unexpectedly succeeded" >&2
  exit 1
fi
REMOTE_AFTER_INVALID_REF=$(git --git-dir="$REMOTE" rev-parse refs/heads/main)
test "$REMOTE_AFTER_INVALID_REF" = "$REMOTE_BEFORE_INVALID_REF"

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
