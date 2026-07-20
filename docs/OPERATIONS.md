# Operations Guide

Run commands from the repository root. Windows PowerShell 5.1 and PowerShell 7 are supported.

```powershell
cd "$env:USERPROFILE\agent-system"
```

## First-Time Setup

```powershell
.\scripts\setup-agent-system.ps1
```

Setup validates configuration, detects existing Codex, Claude Code, and Gemini CLI directories from adapter metadata, then sequentially builds, verifies, previews, installs, and verifies only detected runtimes.

```powershell
.\scripts\setup-agent-system.ps1 -WhatIf
.\scripts\setup-agent-system.ps1 -Force
```

No runtime folders are created. If none are detected, setup exits with code `2`.

## Ongoing Synchronization

```powershell
.\scripts\sync-agent-system.ps1
```

Default sync validates a clean `main` working tree, runs:

```powershell
git pull --rebase origin main
```

then reloads configuration and refreshes detected runtimes.

```powershell
# Use the current local checkout.
.\scripts\sync-agent-system.ps1 -SkipPull

# Preview without pulling, building, or installing.
.\scripts\sync-agent-system.ps1 -WhatIf

# Reinstall matching runtime files.
.\scripts\sync-agent-system.ps1 -Force
```

Default sync refuses to pull when Git is unavailable, the current branch is not `main`, the working tree contains tracked or untracked changes, or pull/rebase fails. It never stashes, resets, cleans, commits, switches branches, or resolves conflicts automatically.

## Runtime Detection

| Runtime | Directory | Installed file |
|---|---|---|
| Codex | `%USERPROFILE%\.codex` | `AGENTS.md` |
| Claude Code | `%USERPROFILE%\.claude` | `CLAUDE.md` |
| Gemini CLI | `%USERPROFILE%\.gemini` | `GEMINI.md` |

The directories are derived from adapter installation paths rather than duplicated in the orchestration scripts. A directory is sufficient for detection; the instruction file may not yet exist.

Processing order is Codex, Claude Code, then Gemini CLI.

## Refresh Pipeline

```text
Build → verify generated → preview install → install → verify installed
```

The workflow is sequential and fail-fast, not transactional. Earlier successful updates remain installed if a later runtime fails. Restart guidance lists only runtimes whose installed file changed.

## Exit Codes

| Code | Meaning |
|---|---|
| `0` | Success, including already-current files |
| `1` | Validation, build, verification, installation, or unexpected failure |
| `2` | No supported runtime detected |
| `3` | Git precondition or pull failure |

## Advanced Commands

```powershell
.\scripts\build-agent.ps1 -Runtime All
.\scripts\build-agent.ps1 -Runtime All -Check
.\scripts\verify-agent.ps1 -Scope All -Strict
.\scripts\install-agent.ps1 -Runtime codex -WhatIf
.\scripts\install-agent.ps1 -Runtime codex
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
.\scripts\restore-backup.ps1 -List
.\tests\run-tests.ps1
```

Compatibility wrappers remain supported:

```powershell
.\scripts\update-codex-agent.ps1
.\scripts\update-claude-agent.ps1
.\scripts\update-all-agents.ps1
```

## Troubleshooting

### Dirty working tree

```powershell
git status --short
```

Commit, stash, or remove changes yourself, then retry.

### Wrong branch

```powershell
git branch --show-current
git switch main
```

### No runtime detected

Install and launch Codex, Claude Code, or Gemini CLI so its user-level directory exists, then rerun setup or sync.

### Build or verification failure

```powershell
.\scripts\build-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1 -Scope All -Strict
```

### Runtime still uses old behavior

Close active sessions and start a new runtime session after an installed instruction file changes.
