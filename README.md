# Universal Agent System

A small, model-agnostic, runtime-independent agent instruction system. One set of shared instruction modules is the single source of truth; runtime-specific instruction files (Codex `AGENTS.md`, Claude Code `CLAUDE.md`, Gemini CLI `GEMINI.md`, and a generic `SYSTEM_PROMPT.md`) are generated from those modules rather than maintained by hand.

The project is intentionally MVP-focused: generate deterministic instructions, verify them, install one runtime safely, and remain easy to understand and maintain.

---

## Source-of-Truth Model

```text
Shared source modules  (core/ workflows/ capabilities/ memory/)
        │
        ▼
Configuration manifest (config/agent.json)  +  Runtime adapter (adapters/<id>.json)
        │
        ▼
Build compiler (scripts/build-agent.ps1)
        │
        ▼
Generated runtime file (generated/<id>/<file>)
        │
        ▼
Verification (scripts/verify-agent.ps1)
        │
        ▼
Explicit single-runtime installation (scripts/install-agent.ps1)
```

Edit the shared source. Build. Verify. Review. Install one runtime. Verify again.

---

## Model vs Runtime

- **Model** — the shared behavior: how the agent classifies requests, runs discovery, gates on approval, implements, tests, reports, and stays safe. This lives in `core/`, `workflows/`, `capabilities/`, and `memory/`.
- **Runtime** — a delivery target such as Codex, Claude Code, Gemini CLI, or a custom prompt. Runtime differences such as filename, install location, title, and header live in `adapters/<id>.json`.

Adding a runtime should not require duplicating shared behavior.

---

## Folder Responsibilities

| Folder | Responsibility |
|---|---|
| `core/` | Purpose, precedence, request classification, lifecycle, repository context, security, output, failure/fallback, and invariants. |
| `workflows/` | Discovery, approval gate, implementation, project continuity, and global learnings. |
| `capabilities/software-engineering/` | Coding guidelines, testing and verification, and frontend taste. |
| `memory/` | Durable preferences and the reusable learnings bank. |
| `adapters/` | Runtime mechanics only: id, output, install path, title, and header. |
| `config/` | `agent.json` manifest and JSON Schemas. |
| `generated/` | Build artifacts; committed, but never hand-edited. |
| `scripts/` | Build, verify, install, restore, and shared PowerShell helpers. |
| `tests/` | Pester-independent test suite. |
| `backups/` | Timestamped backups; contents are git-ignored. |
| `docs/` | Product, installation, migration, adapter, and operations documentation. |

---

## How To Edit Instructions

Edit only:

```text
core/  workflows/  capabilities/  memory/  config/  adapters/
```

Never edit:

```text
generated/                              (overwritten by the next build)
%USERPROFILE%\.codex\AGENTS.md          (installed copy of a build artifact)
%USERPROFILE%\.claude\CLAUDE.md
%USERPROFILE%\.gemini\GEMINI.md
```

Each shared module should have one top-level heading, contain no runtime-specific home paths, and read cleanly when compiled.

---

## Quick Start

```powershell
cd "$env:USERPROFILE\agent-system"

# Build all generated artifacts.
.\scripts\build-agent.ps1 -Runtime All

# Verify source and generated output.
.\scripts\verify-agent.ps1

# Review generated changes.
git diff -- generated

# Preview one runtime installation.
.\scripts\install-agent.ps1 -Runtime codex -WhatIf

# Install and verify that runtime.
.\scripts\install-agent.ps1 -Runtime codex
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex

# Repeat separately for another runtime when needed.
.\scripts\install-agent.ps1 -Runtime claude -WhatIf
.\scripts\install-agent.ps1 -Runtime claude
.\scripts\verify-agent.ps1 -Scope Installed -Runtime claude

# List backups before restoring.
.\scripts\restore-backup.ps1 -List
```

For the complete Codex build, verification, preview, installation, and installed-verification sequence, use the one-command wrapper:

```powershell
.\scripts\update-codex-agent.ps1
```

The wrapper stops on the first failed step and reminds you to restart Codex after a successful update.

`-Runtime All` is appropriate for build and verification. Installation should be performed one runtime at a time. Where installation accepts `-Runtime All`, it runs sequentially and does not provide an all-or-nothing transaction.

For first-time setup, prerequisites, restart guidance, backup and restore instructions, and troubleshooting, follow the [Installation Guide](docs/INSTALLATION.md). For daily command details, see the [Operations Guide](docs/OPERATIONS.md).

---

## Build, Verify, Install, Restore

- **Build** compiles ordered modules per adapter, adds generated-file warnings and source markers, writes only under `generated/`, and must be deterministic.
- **Verify** checks source configuration, adapters, modules, generated freshness, installed hashes, and behavioral anchors.
- **Install** verifies the selected artifact, restricts writes to approved adapter paths, backs up an existing target, replaces the target through a temporary file, verifies the installed hash, and supports `-WhatIf`.
- **Restore** validates a selected backup and restores it to an approved runtime target.

The approved MVP hardening direction strengthens backup-manifest durability, restore rollback, restore target identity, filesystem-aware path validation, Windows CI, and targeted failure-path testing. It intentionally does not add a transaction engine, recovery journal, operational dashboard, or enterprise deployment layer.

Until that hardening is implemented and verified, install and verify one runtime at a time and treat replacement as verified temporary-file replacement rather than a proven atomic operation.

---

## Why Generated Files Must Not Be Edited Manually

Generated files are disposable build artifacts. Manual edits are lost on the next build and create drift between source and deployed instructions. `build-agent.ps1 -Check` and `verify-agent.ps1` detect stale generated files. Always change behavior in the shared modules and rebuild.

---

## Testing

```powershell
.\tests\run-tests.ps1
```

The test suite is self-contained and uses temporary directories rather than real runtime paths. The MVP hardening backlog adds Windows CI and focused failure tests for backup persistence, replacement failures, restore validation, and rollback.

---

## MVP Boundaries

The MVP is designed for safe, maintainable personal use. The following are deferred unless a demonstrated need justifies them:

- transactional multi-runtime installation;
- transaction journals and interrupted-operation recovery;
- structured JSON operation logs;
- `doctor`, `status`, and recovery dashboards;
- backup retention infrastructure;
- release signing and formal certification;
- enterprise deployment and hosted synchronization.

---

## Documentation

- [Product Requirements Document](docs/PRD.md) — MVP vision, requirements, safety direction, limitations, and deferred ideas.
- [Installation Guide](docs/INSTALLATION.md) — prerequisites, build, verification, single-runtime installation, restart, backup, restore, and troubleshooting.
- [Operations Guide](docs/OPERATIONS.md) — executable day-to-day maintenance commands.
- [Runtime Adapter Guide](docs/RUNTIME_ADAPTER_GUIDE.md) — adapter schema and how to add a runtime.
- [Migration Report](docs/MIGRATION_REPORT.md) — inventory, backup, rule mapping, and behavioral-equivalence review.
