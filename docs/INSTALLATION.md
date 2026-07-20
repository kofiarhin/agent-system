# Universal Agent System — Installation Guide

This guide installs the Agent System into detected Codex, Claude Code, and Gemini CLI runtimes on Windows.

## How Installation Works

The repository remains the source of truth. Supported runtimes read installed copies:

```text
shared source
  → generated runtime artifact
  → installed runtime file
  → new runtime session
```

Installed targets:

```text
Codex:       %USERPROFILE%\.codex\AGENTS.md
Claude Code: %USERPROFILE%\.claude\CLAUDE.md
Gemini CLI:  %USERPROFILE%\.gemini\GEMINI.md
```

Do not edit generated or installed files manually.

## Requirements

- Windows 10 or Windows 11;
- Windows PowerShell 5.1 or PowerShell 7;
- Git;
- at least one supported runtime installed and launched once:
  - Codex;
  - Claude Code;
  - Gemini CLI.

Launching the runtime once should create its user-level directory. Agent System does not install runtime applications and does not create missing runtime directories.

## Clone

HTTPS:

```powershell
cd $env:USERPROFILE
git clone https://github.com/kofiarhin/agent-system.git
cd .\agent-system
```

SSH:

```powershell
cd $env:USERPROFILE
git clone git@github.com:kofiarhin/agent-system.git
cd .\agent-system
```

## Preview First-Time Setup

```powershell
.\scripts\setup-agent-system.ps1 -WhatIf
```

Preview detects supported runtime directories and shows what would be built and installed. It does not build, install, or create runtime folders.

## Run First-Time Setup

```powershell
.\scripts\setup-agent-system.ps1
```

The command:

1. validates the repository manifest;
2. validates Codex, Claude Code, and Gemini CLI adapters;
3. derives detection directories from adapter installation paths;
4. detects only directories that already exist;
5. builds each detected runtime artifact;
6. verifies generated output strictly;
7. previews installation;
8. installs sequentially using existing backup and rollback behavior;
9. verifies each installed file;
10. reports which runtimes need restarting.

Processing order:

```text
Codex → Claude Code → Gemini CLI
```

The workflow is sequential and fail-fast, not transactional. An earlier successful runtime remains updated if a later runtime fails.

## Detection Rules

| Runtime | Detection directory | Installed file |
|---|---|---|
| Codex | `%USERPROFILE%\.codex` | `AGENTS.md` |
| Claude Code | `%USERPROFILE%\.claude` | `CLAUDE.md` |
| Gemini CLI | `%USERPROFILE%\.gemini` | `GEMINI.md` |

The instruction file itself does not need to exist. The parent runtime directory must already exist.

When none are detected, setup exits with code `2` and writes nothing.

## Restart

After setup changes an installed file, close active sessions and start a new session for the affected runtime. Existing sessions may continue using previously loaded instructions.

## Ongoing Updates

After initial setup, use:

```powershell
.\scripts\sync-agent-system.ps1
```

The command validates Git state, runs:

```powershell
git pull --rebase origin main
```

then refreshes every detected runtime.

Developers can use the current local checkout:

```powershell
.\scripts\sync-agent-system.ps1 -SkipPull
```

Preview synchronization without pulling, building, or installing:

```powershell
.\scripts\sync-agent-system.ps1 -WhatIf
```

Force reinstall matching files:

```powershell
.\scripts\sync-agent-system.ps1 -Force
```

## Git Safety

Default synchronization stops when:

- Git is unavailable;
- the repository is not a Git working tree;
- the current branch is not `main`;
- tracked or untracked changes exist;
- pull or rebase fails.

It never stashes, resets, cleans, commits, switches branches, or resolves conflicts automatically.

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success, including already-current files |
| `1` | Validation, build, verification, installation, or unexpected failure |
| `2` | No supported runtime detected |
| `3` | Git precondition or pull failure |

## Manual and Advanced Commands

The lower-level commands remain supported:

```powershell
.\scripts\build-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1 -Scope All -Strict
.\scripts\install-agent.ps1 -Runtime codex -WhatIf
.\scripts\install-agent.ps1 -Runtime codex
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
.\scripts\restore-backup.ps1 -List
.\tests\run-tests.ps1
```

Compatibility wrappers remain available:

```powershell
.\scripts\update-codex-agent.ps1
.\scripts\update-claude-agent.ps1
.\scripts\update-all-agents.ps1
```

## Restore

List backups:

```powershell
.\scripts\restore-backup.ps1 -List
```

Preview and restore the latest runtime backup:

```powershell
.\scripts\restore-backup.ps1 -Latest -Runtime codex -WhatIf
.\scripts\restore-backup.ps1 -Latest -Runtime codex
```

## Troubleshooting

### No runtime detected

Install and launch Codex, Claude Code, or Gemini CLI first. Confirm one of these directories exists:

```powershell
Test-Path "$env:USERPROFILE\.codex"
Test-Path "$env:USERPROFILE\.claude"
Test-Path "$env:USERPROFILE\.gemini"
```

### Dirty working tree

```powershell
git status --short
```

Commit, stash, or remove local changes yourself, then rerun sync.

### Wrong branch

```powershell
git branch --show-current
git switch main
```

### Verification failure

```powershell
.\scripts\build-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1 -Scope All -Strict
```

### Runtime still behaves as before

Restart the affected application or open a new session after installation.

For day-to-day commands, see [OPERATIONS.md](OPERATIONS.md). For design details, see [SETUP_AND_SYNC_SPEC.md](SETUP_AND_SYNC_SPEC.md).
