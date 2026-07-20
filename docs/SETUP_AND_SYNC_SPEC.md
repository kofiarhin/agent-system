# Streamlined Setup and Sync Specification

**Status:** Implemented  
**Supported runtimes:** Codex, Claude Code, Gemini CLI  
**Primary platform:** Windows PowerShell 5.1 and PowerShell 7

## Summary

Universal Agent System provides two high-level commands:

```powershell
.\scripts\setup-agent-system.ps1
.\scripts\sync-agent-system.ps1
```

Setup performs first-time installation from an already cloned repository. Sync performs safe repository synchronization and refreshes detected runtimes.

Both commands reuse the existing build, verification, installation, backup, rollback, and installed-hash primitives. They do not introduce cross-runtime transactions.

## Goals

The implementation must:

- provide one first-time setup command;
- provide one ongoing synchronization command;
- detect Codex, Claude Code, and Gemini CLI automatically;
- derive detection directories from adapter installation metadata;
- install only detected runtimes;
- avoid creating missing runtime directories;
- run `git pull --rebase origin main` during normal sync;
- provide `-SkipPull` for developers;
- preserve sequential, fail-fast processing;
- support `-WhatIf`, `-Force`, and `-Confirm`;
- report outcomes and restart guidance accurately;
- remain compatible with PowerShell 5.1 and PowerShell 7.

## Non-Goals

This work does not:

- install runtime applications;
- clone the repository automatically;
- create `.codex`, `.claude`, or `.gemini` directories;
- support additional automatic runtimes;
- run as a background service or scheduled updater;
- restart runtime applications;
- perform cross-runtime rollback;
- alter local Git work automatically;
- provide hosted or enterprise synchronization.

## Runtime Detection

| Runtime | Adapter ID | Detection directory | Installed file |
|---|---|---|---|
| Codex | `codex` | `%USERPROFILE%\.codex` | `AGENTS.md` |
| Claude Code | `claude` | `%USERPROFILE%\.claude` | `CLAUDE.md` |
| Gemini CLI | `gemini` | `%USERPROFILE%\.gemini` | `GEMINI.md` |

A runtime is detected when:

1. its adapter is in the supported allowlist;
2. the adapter is enabled;
3. installation is supported;
4. the install path resolves successfully;
5. the target is inside an approved root;
6. the target file's parent directory already exists.

The instruction file itself may be absent. Detection is read-only and must not create directories or files.

## Setup Workflow

```powershell
.\scripts\setup-agent-system.ps1
```

Setup:

1. resolves the repository root;
2. validates the manifest and supported adapters;
3. detects supported runtimes;
4. exits with code `2` when none are detected;
5. processes detected runtimes in deterministic order;
6. prints a final summary and restart guidance.

Setup does not run Git pull.

## Sync Workflow

```powershell
.\scripts\sync-agent-system.ps1
```

Default sync:

1. requires Git;
2. requires a Git working tree;
3. requires branch `main`;
4. requires a clean working tree including untracked files;
5. runs `git pull --rebase origin main`;
6. reloads configuration after the pull;
7. detects supported runtimes;
8. refreshes detected runtimes;
9. reports outcomes and restart guidance.

Developer override:

```powershell
.\scripts\sync-agent-system.ps1 -SkipPull
```

Sync must never automatically stash, reset, clean, commit, switch branches, or resolve conflicts.

## Refresh Pipeline

Runtime order:

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

Processing is sequential and fail-fast. Earlier successful runtimes remain updated when a later runtime fails. Later runtimes are not attempted after failure.

## Command Options

### Setup

```powershell
.\scripts\setup-agent-system.ps1 -WhatIf
.\scripts\setup-agent-system.ps1 -Force
.\scripts\setup-agent-system.ps1 -Confirm
```

### Sync

```powershell
.\scripts\sync-agent-system.ps1 -SkipPull
.\scripts\sync-agent-system.ps1 -WhatIf
.\scripts\sync-agent-system.ps1 -Force
.\scripts\sync-agent-system.ps1 -Confirm
```

`-WhatIf` must not pull, build, or install. `-Force` forwards reinstall intent. `-Confirm` applies to the high-level operation.

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | All intended operations succeeded; already-current files count as success |
| `1` | Validation, build, verification, installation, or unexpected failure |
| `2` | No supported runtime detected |
| `3` | Git precondition or pull failure |

## Safety Requirements

The high-level workflows must preserve:

- deterministic builds;
- manifest and adapter validation;
- generated artifact verification;
- approved-root path validation;
- reparse-point defenses;
- hash-verified backups;
- temporary-file replacement;
- installed hash verification;
- affected-runtime rollback;
- sandbox repositories and temporary target maps in tests.

## Backward Compatibility

The following commands remain supported:

```powershell
.\scripts\build-agent.ps1
.\scripts\verify-agent.ps1
.\scripts\install-agent.ps1
.\scripts\restore-backup.ps1
.\scripts\update-codex-agent.ps1
.\scripts\update-claude-agent.ps1
.\scripts\update-all-agents.ps1
```

Setup and sync are the recommended user-facing entry points. The older commands remain advanced or compatibility interfaces.

## Acceptance Criteria

The implementation is accepted when:

- setup detects any supported runtime combination;
- no-runtime setup exits safely without writing;
- sync safely updates from `origin/main`;
- dirty and wrong-branch states are rejected without modification;
- `-SkipPull`, `-WhatIf`, `-Force`, and `-Confirm` behave as documented;
- runtime paths derive from adapters;
- runtime processing is deterministic and fail-fast;
- partial success is reported accurately;
- restart guidance lists changed runtimes only;
- automated tests never touch real runtime folders;
- README, PRD, installation, operations, adapter, specification, and implementation documents describe the same direction.
