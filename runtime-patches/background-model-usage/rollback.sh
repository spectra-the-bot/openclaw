#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./patch-meta.sh
source "$SCRIPT_DIR/patch-meta.sh"

TARGET_ROOT="${1:-/opt/homebrew/lib/node_modules/openclaw}"
TARGET_FILE="$TARGET_ROOT/$TARGET_REL_PATH"
PATCH_FILE="$SCRIPT_DIR/$PATCH_FILE_NAME"

if ! command -v patch >/dev/null 2>&1; then
  echo "ERROR: 'patch' command not found. Install patch(1) and retry." >&2
  exit 127
fi

if [[ ! -f "$TARGET_FILE" ]]; then
  echo "ERROR: target file not found: $TARGET_FILE" >&2
  exit 2
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "ERROR: patch artifact not found: $PATCH_FILE" >&2
  exit 2
fi

current_hash="$(hash_file_sha256 "$TARGET_FILE")"

if [[ "$current_hash" == "$EXPECTED_PRE_PATCH_SHA256" ]]; then
  echo "OK: target already in pre-patch state. Nothing to rollback."
  exit 0
fi

if [[ "$current_hash" != "$EXPECTED_POST_PATCH_SHA256" ]]; then
  cat >&2 <<EOF
ERROR: cannot rollback because target hash is neither expected pre nor expected post value.
Target: $TARGET_FILE
Expected pre:  $EXPECTED_PRE_PATCH_SHA256
Expected post: $EXPECTED_POST_PATCH_SHA256
Actual:        $current_hash

This runtime appears to have drifted; regenerate patch artifacts for this version.
EOF
  exit 3
fi

patch -R -p1 -d "$TARGET_ROOT" < "$PATCH_FILE"

post_rollback_hash="$(hash_file_sha256 "$TARGET_FILE")"
if [[ "$post_rollback_hash" != "$EXPECTED_PRE_PATCH_SHA256" ]]; then
  cat >&2 <<EOF
ERROR: rollback hash verification failed.
Expected pre-patch hash: $EXPECTED_PRE_PATCH_SHA256
Actual hash:             $post_rollback_hash
EOF
  exit 4
fi

echo "OK: rollback complete for $PATCH_ID"
echo "Target: $TARGET_FILE"
echo "Hash:   $post_rollback_hash"
