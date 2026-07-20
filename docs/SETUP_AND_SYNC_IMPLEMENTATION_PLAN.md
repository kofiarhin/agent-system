# Streamlined Setup and Sync Implementation Record

**Related specification:** [`SETUP_AND_SYNC_SPEC.md`](SETUP_AND_SYNC_SPEC.md)  
**Delivery model:** Direct implementation on `main` as explicitly authorized  
**Current status:** Implemented

## Objective

Provide two user-facing PowerShell entry points:

```powershell
.\scripts\setup-agent-system.ps1
.\scripts\sync-agent-system.ps1
```

Setup installs Agent System instructions into detected Codex, Claude Code, and Gemini CLI runtime directories from the current checkout. Sync safely updates the repository from `origin/main` and refreshes the same detected runtimes.

## Implemented Files

### User-facing commands

```text
scripts/setup-agent-system.ps1
scripts/sync-agent-system.ps1
```

### Shared workflow libraries

```text
scripts/lib/RuntimeDetection.ps1
scripts/lib/RefreshWorkflow.ps1
```

### Tests

```text
tests/setup-sync.Tests.ps1
tests/run-tests.ps1
```

### Documentation aligned with the direction

```text
README.md
docs/PRD.md
docs/INSTALLATION.md
docs/OPERATIONS.md
docs/RUNTIME_ADAPTER_GUIDE.md
docs/SETUP_AND_SYNC_SPEC.md
docs/SETUP_AND_SYNC_IMPLEMENTATION_PLAN.md
```

## Implemented Architecture

### Runtime detection

Detection:

- supports Codex, Claude Code, and Gemini CLI;
- reads adapter metadata rather than duplicating runtime paths;
- requires enabled, installable adapters;
- validates resolved targets against approved roots;
- derives the detection directory from the parent of `installation.path`;
- considers the runtime detected when that directory exists;
- does not require the instruction file to exist;
- never creates runtime directories or files.

### Shared refresh workflow

Each detected runtime is processed in deterministic order:

```text
Codex → Claude Code → Gemini CLI
```

Per runtime:

```text
Build
→ verify generated output
→ preview installation
→ install
→ verify installed output
```

The implementation reuses existing build, verification, installation, backup, rollback, approved-root, and installed-hash behavior.

### Git synchronization

Default sync:

- requires Git;
- requires a Git working tree;
- requires branch `main`;
- requires a clean working tree including untracked files;
- runs `git pull --rebase origin main` with fixed argument tokens;
- reloads configuration after the pull;
- stops on pull or rebase failure;
- never stashes, resets, cleans, commits, switches branches, or resolves conflicts.

`-SkipPull` uses the current checkout while preserving all non-Git validation.

## Command Surface

### Setup

```powershell
.\scripts\setup-agent-system.ps1
.\scripts\setup-agent-system.ps1 -WhatIf
.\scripts\setup-agent-system.ps1 -Force
.\scripts\setup-agent-system.ps1 -Confirm
```

### Sync

```powershell
.\scripts\sync-agent-system.ps1
.\scripts\sync-agent-system.ps1 -SkipPull
.\scripts\sync-agent-system.ps1 -WhatIf
.\scripts\sync-agent-system.ps1 -Force
.\scripts\sync-agent-system.ps1 -Confirm
```

## Failure Semantics

The workflow is sequential and fail-fast, not transactional.

When an earlier runtime succeeds and a later runtime fails:

- the earlier runtime remains updated;
- later runtimes are not attempted;
- the summary reports partial success accurately;
- there is no cross-runtime rollback.

Exit codes:

| Code | Meaning |
|---|---|
| `0` | Success, including already-current files |
| `1` | Validation, build, verification, installation, or unexpected failure |
| `2` | No supported runtime detected |
| `3` | Git precondition or pull failure |

## Safety Guarantees Preserved

- deterministic generated artifacts;
- strict generated verification;
- adapter-derived approved targets;
- approved-root and reparse-point defenses;
- timestamped hash-verified backups;
- temporary-file installation;
- installed hash verification;
- affected-runtime rollback on installation failure;
- sandbox repositories and temporary target maps in tests;
- no writes to real runtime directories during automated tests.

## Backward Compatibility

The following lower-level and compatibility commands remain supported:

```powershell
.\scripts\build-agent.ps1
.\scripts\verify-agent.ps1
.\scripts\install-agent.ps1
.\scripts\restore-backup.ps1
.\scripts\update-codex-agent.ps1
.\scripts\update-claude-agent.ps1
.\scripts\update-all-agents.ps1
```

Setup and sync are the recommended user-facing workflows. The lower-level commands are advanced interfaces for development, diagnosis, and targeted recovery.

## Verification

The repository contains isolated tests for runtime detection and refresh orchestration. The full local verification command is:

```powershell
.\tests\run-tests.ps1
```

Tests must run under supported PowerShell environments and must never touch production runtime locations.

## Remaining Product Boundaries

The implementation does not provide:

- runtime application installation;
- missing runtime directory creation;
- background or scheduled updates;
- automatic runtime restart;
- additional automatic runtime adapters beyond Codex, Claude Code, and Gemini CLI;
- cross-runtime transactions;
- automatic Git conflict or local-change resolution;
- hosted or enterprise synchronization.

Any expansion requires separate discovery, approval, implementation, and verification.
