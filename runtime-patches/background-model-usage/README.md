# OpenClaw hotfix: background `model.usage` diagnostics

This folder contains a deterministic, hash-guarded local patch for the runtime bug where non-interactive/background `agent` runs can miss `model.usage` diagnostic events.

## Why this target

Preferred immediate target (for globally npm-installed OpenClaw):

- `dist/reply-DeXK9BLT.js`
- Default absolute path on this machine: `/opt/homebrew/lib/node_modules/openclaw/dist/reply-DeXK9BLT.js`

Reason: the live install executes bundled `dist/*` artifacts directly. Patching `src/*` in this repo does **not** change an already-installed global runtime unless you rebuild and reinstall.

Durable upstream target (already fixed in repo source as reference):

- `src/commands/agent.ts`

Use source patching when you control the build/install pipeline and can regenerate `dist` during install.

## Hash guard (deterministic safety check)

The scripts require an exact pre-patch SHA-256 before patching:

- Pre-patch hash: `e861814127e0aa1df64d7e9ef3b68673c1fe4cea24f60481f25f4d2284716e47`
- Post-patch hash: `4cc7bdd384970a0acc5367607eb7471431c8e52fad515a583d7303a015bc87f9`

If the current file hash differs from the expected pre-patch hash, apply fails nonzero with a clear drift warning.

## Files

- `reply-DeXK9BLT.model-usage.patch` — unified diff patch artifact
- `patch-meta.sh` — shared patch constants + hash values
- `apply.sh` — guarded patch apply script
- `verify.sh` — hash/state verification script
- `rollback.sh` — guarded rollback script

## Usage (on a machine with global npm-installed OpenClaw)

From this directory:

```bash
# 1) Check state (should usually report state=pre before first apply)
./verify.sh /opt/homebrew/lib/node_modules/openclaw --expect=pre

# 2) Apply patch (creates a backup file next to target)
./apply.sh /opt/homebrew/lib/node_modules/openclaw

# 3) Verify patched state
./verify.sh /opt/homebrew/lib/node_modules/openclaw --expect=post
```

## Rollback

```bash
./rollback.sh /opt/homebrew/lib/node_modules/openclaw
./verify.sh /opt/homebrew/lib/node_modules/openclaw --expect=pre
```

## Failure mode on version drift

`apply.sh` exits nonzero **before patching** when target hash is not exactly the expected pre-patch value. This prevents accidental patching of a different OpenClaw build and instructs you to regenerate patch artifacts for that version.
