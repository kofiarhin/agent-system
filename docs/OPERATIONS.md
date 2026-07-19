# Operations Guide

Executable PowerShell for day-to-day maintenance. Run from the repository root.
All commands are PowerShell 7 compatible and also run under Windows PowerShell 5.1.

```powershell
cd "$env:USERPROFILE\agent-system"
```

---

## One-command Codex update

Use this after changing shared instructions, configuration, adapters, or generated Codex behavior:

```powershell
.\scripts\update-codex-agent.ps1
```

The wrapper runs the supported Codex workflow in order:

1. build the Codex artifact;
2. verify generated output;
3. preview installation with `-WhatIf`;
4. install the Codex artifact;
5. verify the installed copy.

It stops immediately on failure and returns a non-zero exit code. Restart Codex after a successful update so new sessions load the installed instructions.

---

## Build

```powershell
# Build every enabled runtime.
.\scripts\build-agent.ps1 -Runtime All

# Build a single runtime.
.\scripts\build-agent.ps1 -Runtime codex

# Verbose compilation detail.
.\scripts\build-agent.ps1 -Runtime All -Verbose

# Remove generated files known to the configuration (no build).
.\scripts\build-agent.ps1 -Runtime All -Clean

# Fail (exit 2) if any checked-in generated file is stale. Does not write.
.\scripts\build-agent.ps1 -Runtime All -Check
```

The build never installs. It writes only under `generated/`, atomically, and skips
files whose content is unchanged.

---

## Verify

```powershell
# Verify source + generated (default).
.\scripts\verify-agent.ps1

# Individual scopes.
.\scripts\verify-agent.ps1 -Scope Source
.\scripts\verify-agent.ps1 -Scope Generated
.\scripts\verify-agent.ps1 -Scope Installed

# Restrict to one runtime; treat warnings as failures.
.\scripts\verify-agent.ps1 -Scope Generated -Runtime codex -Strict
```

Verification checks manifest/adapter validity, module existence and ordering,
prohibited runtime paths, generated warnings, titles, headers, source markers,
unresolved variables, deterministic clean rebuild, freshness, installed hashes, and
behavioral anchors. Non-zero exit on any failure.

---

## Preview installation (no changes)

```powershell
.\scripts\install-agent.ps1 -Runtime All -WhatIf
```

`-WhatIf` prints the plan (source artifact, target path, whether a backup would be
created, whether the target exists) and writes nothing.

---

## Install (after review)

```powershell
# Install all enabled, installable runtimes.
.\scripts\install-agent.ps1 -Runtime All

# Install one runtime; reinstall even if already current.
.\scripts\install-agent.ps1 -Runtime codex -Force
```

The installer verifies the generated artifact, confirms the target is an approved
adapter path, backs up any existing target (hash-verified), installs through a
temporary file, replaces atomically, verifies the installed hash, and rolls back from
the verified backup on a failed replacement.

```powershell
# Confirm installed files match generated artifacts.
.\scripts\verify-agent.ps1 -Scope Installed
```

---

## Restore

```powershell
# List available backups.
.\scripts\restore-backup.ps1 -List

# Restore the latest backup for one runtime (preview first).
.\scripts\restore-backup.ps1 -Latest -Runtime codex -WhatIf
.\scripts\restore-backup.ps1 -Latest -Runtime codex

# Restore a specific backup for all runtimes it contains.
.\scripts\restore-backup.ps1 -BackupId 20260719-031433Z -Runtime All
```

Restore validates the backup manifest and hashes, backs up the current target before
restoring, restores atomically, verifies restored hashes, and rejects targets outside
approved runtime roots.

---

## Tests

```powershell
# Full suite (Pester-independent; temp directories only).
.\tests\run-tests.ps1

# A single suite standalone.
.\tests\build-agent.Tests.ps1
.\tests\verify-agent.Tests.ps1
.\tests\install-agent.Tests.ps1
.\tests\restore-backup.Tests.ps1
```

Tests never install to real `.codex` / `.claude` / `.gemini` paths.

---

## Standard update workflow

```powershell
cd "$env:USERPROFILE\agent-system"

# 1. Edit shared source only (core/ workflows/ capabilities/ memory/ config/ adapters/).
# 2. Rebuild and verify.
.\scripts\build-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1

# 3. Review the generated diff.
git diff -- generated

# 4. Preview, then install.
.\scripts\install-agent.ps1 -Runtime All -WhatIf
.\scripts\install-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1 -Scope Installed

# 5. Commit.
git add .
git commit -m "chore: update shared agent instructions"
```

Never edit `generated/` or the installed runtime files directly; the next build
overwrites `generated/`, and installed files are copies of build artifacts.
