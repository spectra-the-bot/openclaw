#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./patch-meta.sh
source "$SCRIPT_DIR/patch-meta.sh"

TARGET_ROOT="${1:-/opt/homebrew/lib/node_modules/openclaw}"
TARGET_FILE="$TARGET_ROOT/$TARGET_REL_PATH"
PATCH_FILE="$SCRIPT_DIR/$PATCH_FILE_NAME"
BACKUP_FILE="$TARGET_FILE.bak.${PATCH_ID}.${EXPECTED_PRE_PATCH_SHA256:0:12}"

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

if [[ "$current_hash" == "$EXPECTED_POST_PATCH_SHA256" ]]; then
  echo "OK: patch already applied ($PATCH_ID)."
  exit 0
fi

if [[ "$current_hash" != "$EXPECTED_PRE_PATCH_SHA256" ]]; then
  cat >&2 <<EOF
ERROR: hash mismatch for $TARGET_FILE
Expected pre-patch hash: $EXPECTED_PRE_PATCH_SHA256
Actual hash:            $current_hash

Refusing to patch because this OpenClaw install drifted from the vetted build.
Regenerate the patch artifacts against the currently installed runtime version.
EOF
  exit 3
fi

if [[ ! -f "$BACKUP_FILE" ]]; then
  cp -p "$TARGET_FILE" "$BACKUP_FILE"
  echo "Created backup: $BACKUP_FILE"
fi

patch -p1 -d "$TARGET_ROOT" < "$PATCH_FILE"

post_hash="$(hash_file_sha256 "$TARGET_FILE")"
if [[ "$post_hash" != "$EXPECTED_POST_PATCH_SHA256" ]]; then
  cat >&2 <<EOF
ERROR: post-patch hash verification failed.
Expected patched hash: $EXPECTED_POST_PATCH_SHA256
Actual hash:           $post_hash

Your runtime may be in an unknown state. Restore from backup:
  cp "$BACKUP_FILE" "$TARGET_FILE"
EOF
  exit 4
fi

echo "OK: applied $PATCH_ID"
echo "Target: $TARGET_FILE"
echo "Hash:   $post_hash"
