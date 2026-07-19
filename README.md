# Universal Agent System

A model-agnostic, runtime-independent agent instruction system. One set of shared
instruction modules is the single source of truth; runtime-specific instruction files
(Codex `AGENTS.md`, Claude Code `CLAUDE.md`, Gemini CLI `GEMINI.md`, a generic
`SYSTEM_PROMPT.md`) are **generated** from those modules, not maintained by hand.

It preserves the structure, lifecycle, safeguards, coding preferences, verification
behavior, and output rules of the original global Codex instruction architecture while
removing runtime-specific coupling.

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
Explicit installation (scripts/install-agent.ps1)  →  runtime config directory
```

Edit the shared source. Build. Verify. Review. Install. Verify again.

---

## Model vs Runtime

- **Model** — the shared *behavior*: how the agent classifies requests, runs
  discovery, gates on approval, implements, tests, reports, and stays safe. This is
  identical across every runtime and lives in `core/`, `workflows/`, `capabilities/`,
  and `memory/`.
- **Runtime** — a *delivery target* (Codex, Claude Code, Gemini CLI, a custom prompt).
  A runtime differs only in file name, install location, document title, and a short
  header describing how it resolves its own instruction files. That lives in
  `adapters/<id>.json`.

Adding a runtime never requires changing shared behavior.

---

## Folder Responsibilities

| Folder | Responsibility |
|---|---|
| `core/` | Purpose, precedence, request classification, lifecycle, repository context, security, output, failure/fallback, invariants. |
| `workflows/` | Discovery, approval gate, implementation, project continuity, global learnings. |
| `capabilities/software-engineering/` | Coding guidelines, testing & verification, frontend taste. |
| `memory/` | Durable preferences and the reusable learnings bank (kept alongside source, not compiled into the runtime document). |
| `adapters/` | Runtime mechanics only (id, output, install path, title, header). |
| `config/` | `agent.json` manifest + JSON Schemas. |
| `generated/` | Build artifacts (committed, never hand-edited). |
| `scripts/` | Build, verify, install, restore + shared PowerShell library. |
| `tests/` | Pester-independent test suite. |
| `backups/` | Timestamped, hash-verified backups (contents git-ignored). |
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

Each shared module has one top-level heading, contains no runtime-specific home paths,
and reads cleanly when concatenated into the compiled document.

---

## Quick Start

```powershell
cd "$env:USERPROFILE\agent-system"

# Build all runtimes.
.\scripts\build-agent.ps1 -Runtime All

# Verify source and generated output.
.\scripts\verify-agent.ps1

# Review the generated runtime files.
git diff -- generated

# Preview installation (no changes).
.\scripts\install-agent.ps1 -Runtime All -WhatIf

# Install after review, then confirm.
.\scripts\install-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1 -Scope Installed

# Restore if needed.
.\scripts\restore-backup.ps1 -List
.\scripts\restore-backup.ps1 -Latest -Runtime All
```

For first-time setup, prerequisites, individual runtime installation, restart guidance,
and troubleshooting, follow the [Installation Guide](docs/INSTALLATION.md). For daily
command details, see the [Operations Guide](docs/OPERATIONS.md).

---

## Build, Verify, Install, Restore (summary)

- **Build** compiles ordered modules per adapter, adds a generated-file warning,
  runtime title, runtime header, and `<!-- source: … -->` markers, writes through a
  temporary output, is deterministic, and never installs.
- **Verify** checks manifest/adapters/modules, ordering, prohibited runtime paths,
  generated warnings/titles/headers/markers, unresolved variables, a clean-rebuild
  hash match, installed hashes, and behavioral anchors.
- **Install** verifies the artifact, restricts writes to approved adapter paths, backs
  up and hash-verifies an existing target, replaces the target through a temporary
  file, verifies the installed hash, and attempts rollback on failure. Supports
  `-WhatIf`.
- **Restore** validates a backup, backs up the current target, replaces the approved
  target, and verifies restored hashes.

For production use, install and verify one runtime at a time until multi-runtime
transaction hardening is complete.

---

## Why Generated Files Must Not Be Edited Manually

Generated files are disposable build artifacts. Any manual edit is lost on the next
build and creates drift between the source of truth and the deployed instructions.
`build-agent.ps1 -Check` and `verify-agent.ps1` detect stale generated files so drift
is caught before installation. Always change behavior in the shared modules and rebuild.

---

## Testing

```powershell
.\tests\run-tests.ps1
```

The suite is self-contained (no external dependency) and exercises deterministic
builds, ordering, validation failures, path-traversal rejection, stale detection,
installer backups/rollback/`-WhatIf`, and restore behavior — all in temporary
directories, never against real runtime paths.

---

## Documentation

- [Product Requirements Document](docs/PRD.md) — product vision, users, requirements,
  architecture, current status, limitations, and roadmap.
- [Installation Guide](docs/INSTALLATION.md) — prerequisites, clone, build, verification,
  runtime installation, restart, backup, restore, and troubleshooting.
- [Operations Guide](docs/OPERATIONS.md) — executable day-to-day maintenance commands.
- [Runtime Adapter Guide](docs/RUNTIME_ADAPTER_GUIDE.md) — adapter schema and how to add
  a runtime.
- [Migration Report](docs/MIGRATION_REPORT.md) — inventory, backup, rule mapping, and
  behavioral-equivalence review.
