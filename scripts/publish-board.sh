#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: publish-board.sh SOURCE_PATH TARGET_PATH SOURCE_REPOSITORY SOURCE_SHA" >&2
  exit 2
fi

SOURCE_PATH=$1
TARGET_PATH=$2
SOURCE_REPOSITORY=$3
SOURCE_SHA=$4
SCRIPT_DIRECTORY=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TEMPORARY_TARGET=""

cleanup() {
  if [[ -n "$TEMPORARY_TARGET" ]]; then
    rm -f -- "$TEMPORARY_TARGET"
  fi
}

abort_rebase() {
  git rebase --abort >/dev/null 2>&1 || true
}

trap cleanup EXIT

python3 "$SCRIPT_DIRECTORY/validate-board.py" "$SOURCE_PATH" "$TARGET_PATH"

TARGET_DIRECTORY=$(dirname "$TARGET_PATH")
mkdir -p -- "$TARGET_DIRECTORY"
TEMPORARY_TARGET=$(mktemp "$TARGET_DIRECTORY/.publish-board.XXXXXX")
cp -- "$SOURCE_PATH" "$TEMPORARY_TARGET"
mv -- "$TEMPORARY_TARGET" "$TARGET_PATH"
TEMPORARY_TARGET=""

git add -- "$TARGET_PATH"
if git diff --cached --quiet -- "$TARGET_PATH"; then
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git commit --only \
  -m "chore(boards): publish $TARGET_PATH from $SOURCE_REPOSITORY@$SOURCE_SHA" \
  -- "$TARGET_PATH"

for attempt in 1 2 3 4 5; do
  if ! git pull --rebase origin main; then
    abort_rebase
    if [[ $attempt -eq 5 ]]; then
      echo "error: unable to rebase publication after five attempts" >&2
      exit 1
    fi
    continue
  fi

  if git push origin HEAD:main; then
    exit 0
  fi

  if [[ $attempt -eq 5 ]]; then
    abort_rebase
    echo "error: unable to push publication after five attempts" >&2
    exit 1
  fi
done
