#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./patch-meta.sh
source "$SCRIPT_DIR/patch-meta.sh"

TARGET_ROOT="/opt/homebrew/lib/node_modules/openclaw"
EXPECT_MODE="either" # either|pre|post

for arg in "$@"; do
  case "$arg" in
    --expect=pre|--expect=original)
      EXPECT_MODE="pre"
      ;;
    --expect=post|--expect=patched)
      EXPECT_MODE="post"
      ;;
    --expect=either)
      EXPECT_MODE="either"
      ;;
    --help|-h)
      cat <<EOF
Usage: $(basename "$0") [TARGET_ROOT] [--expect=pre|post|either]

Defaults:
  TARGET_ROOT=/opt/homebrew/lib/node_modules/openclaw
  --expect=either
EOF
      exit 0
      ;;
    --*)
      echo "ERROR: unknown flag: $arg" >&2
      exit 2
      ;;
    *)
      TARGET_ROOT="$arg"
      ;;
  esac
done

TARGET_FILE="$TARGET_ROOT/$TARGET_REL_PATH"
if [[ ! -f "$TARGET_FILE" ]]; then
  echo "ERROR: target file not found: $TARGET_FILE" >&2
  exit 2
fi

hash="$(hash_file_sha256 "$TARGET_FILE")"
state="unknown"
if [[ "$hash" == "$EXPECTED_PRE_PATCH_SHA256" ]]; then
  state="pre"
elif [[ "$hash" == "$EXPECTED_POST_PATCH_SHA256" ]]; then
  state="post"
fi

echo "patch_id=$PATCH_ID"
echo "target=$TARGET_FILE"
echo "state=$state"
echo "sha256=$hash"
echo "expected_pre=$EXPECTED_PRE_PATCH_SHA256"
echo "expected_post=$EXPECTED_POST_PATCH_SHA256"

case "$EXPECT_MODE" in
  either)
    [[ "$state" != "unknown" ]] || exit 1
    ;;
  pre|post)
    [[ "$state" == "$EXPECT_MODE" ]] || exit 1
    ;;
esac
