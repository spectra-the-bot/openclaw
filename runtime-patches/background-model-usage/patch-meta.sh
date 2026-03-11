#!/usr/bin/env bash

# Shared constants for the OpenClaw background model.usage diagnostic hotfix patch.
PATCH_ID="otel-background-model-usage-diagnostics"
TARGET_REL_PATH="dist/reply-DeXK9BLT.js"
PATCH_FILE_NAME="reply-DeXK9BLT.model-usage.patch"

# Hash guard values (sha256)
EXPECTED_PRE_PATCH_SHA256="e861814127e0aa1df64d7e9ef3b68673c1fe4cea24f60481f25f4d2284716e47"
EXPECTED_POST_PATCH_SHA256="4cc7bdd384970a0acc5367607eb7471431c8e52fad515a583d7303a015bc87f9"

hash_file_sha256() {
  local file="$1"
  shasum -a 256 "$file" | awk '{print $1}'
}
