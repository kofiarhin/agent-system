# Universal Agent System

A small, model-agnostic, runtime-independent agent instruction system. One set of shared instruction modules is the single source of truth; runtime-specific instruction files for Codex, Claude Code, Gemini CLI, and generic agents are generated rather than maintained by hand.

## Source-of-Truth Model

```text
Shared modules (core/ workflows/ capabilities/ memory/)
        ↓
Manifest + runtime adapter
        ↓
Deterministic build
        ↓
Generated runtime artifact
        ↓
Verification
        ↓
Detected-runtime installation
```

The LLM runtime reads its installed instruction file, not the repository directly.

## Quick Start

Install at least one supported runtime and launch it once so its user-level directory exists:

```text
%USERPROFILE%\.codex
%USERPROFILE%\.claude
%USERPROFILE%\.gemini
```

Clone the repository, then run the first-time setup command:

```powershell
cd $env:USERPROFILE
git clone https://github.com/kofiarhin/agent-system.git
cd .\agent-system
.\scripts\setup-agent-system.ps1
```

The setup command detects Codex, Claude Code, and Gemini CLI from adapter-defined runtime directories. It builds, verifies, previews, installs, and verifies only the runtimes detected on the machine.

For future updates, run one command:

```powershell
.\scripts\sync-agent-system.ps1
```

Synchronization validates a clean `main` working tree, runs `git pull --rebase origin main`, reloads configuration, detects supported runtimes, and refreshes them sequentially.

Developers working from local source can skip the pull:

```powershell
.\scripts\sync-agent-system.ps1 -SkipPull
```

Preview without pulling, building, or installing:

```powershell
.\scripts\sync-agent-system.ps1 -WhatIf
```

## Supported Runtimes

| Runtime | Adapter | Installed file |
|---|---|---|
| Codex | `adapters/codex.json` | `%USERPROFILE%\.codex\AGENTS.md` |
| Claude Code | `adapters/claude.json` | `%USERPROFILE%\.claude\CLAUDE.md` |
| Gemini CLI | `adapters/gemini.json` | `%USERPROFILE%\.gemini\GEMINI.md` |

Detection paths are derived from adapter installation metadata. The setup and sync commands do not create missing runtime directories and do not install the runtime applications themselves.

## Safety Model

Runtime refresh remains one runtime at a time internally and is sequential, not transactional. The order is Codex, Claude Code, then Gemini CLI. A failure stops later runtimes, while an earlier successfully updated runtime remains updated and is reported accurately.

Each processed runtime follows:

```text
Build → verify generated → preview install → install → verify installed
```

Existing build, verification, approved-path validation, backup, rollback, and hash-verification behavior remains authoritative.

The default sync command refuses to pull when Git is unavailable, the current branch is not `main`, or the working tree contains tracked or untracked changes. It never stashes, resets, cleans, commits, switches branches, or resolves conflicts automatically.

## Editing Instructions

Edit only:

```text
core/  workflows/  capabilities/  memory/  config/  adapters/
```

Never hand-edit generated or installed copies:

```text
generated/
%USERPROFILE%\.codex\AGENTS.md
%USERPROFILE%\.claude\CLAUDE.md
%USERPROFILE%\.gemini\GEMINI.md
```

## Advanced Commands

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

Compatibility wrappers also remain available:

```powershell
.\scripts\update-codex-agent.ps1
.\scripts\update-claude-agent.ps1
.\scripts\update-all-agents.ps1
```

## Documentation

- [Installation Guide](docs/INSTALLATION.md)
- [Operations Guide](docs/OPERATIONS.md)
- [Setup and Sync Specification](docs/SETUP_AND_SYNC_SPEC.md)
- [Setup and Sync Implementation Plan](docs/SETUP_AND_SYNC_IMPLEMENTATION_PLAN.md)
- [Product Requirements Document](docs/PRD.md)
- [Runtime Adapter Guide](docs/RUNTIME_ADAPTER_GUIDE.md)
