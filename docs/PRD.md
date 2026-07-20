# Universal Agent System — Product Requirements Document

**Status:** Implemented streamlined setup and synchronization workflow  
**Primary platform:** Windows with PowerShell 5.1 or later  
**Repository:** `kofiarhin/agent-system`

## 1. Executive Summary

Universal Agent System is a small, model-agnostic instruction system for AI coding runtimes. It keeps reusable behavior in one shared source and generates runtime-native instruction files for Codex, Claude Code, Gemini CLI, and generic/custom use.

The primary product experience is:

```powershell
# First-time installation from an already cloned repository.
.\scripts\setup-agent-system.ps1

# Ongoing repository and runtime synchronization.
.\scripts\sync-agent-system.ps1
```

The system automatically detects supported local runtime directories from adapter installation metadata, then sequentially builds, verifies, previews, installs, and verifies only those runtimes that are present.

## 2. Problem Statement

AI coding runtimes use different instruction filenames, install locations, and precedence rules. Maintaining separate instruction systems causes behavior drift, repeated fixes, manually edited installed files, and unclear traceability.

The original low-level tooling solved generation and safe installation, but required users to understand several separate operations and runtime-specific wrappers. The streamlined product direction keeps those safety primitives while reducing the normal user workflow to setup once and sync thereafter.

## 3. Product Vision

Provide a dependable personal-use instruction system in which:

- shared behavior is authored once;
- each runtime receives its native instruction file;
- generated artifacts are deterministic and reviewable;
- supported runtimes are detected automatically;
- first-time installation is one command;
- ongoing updates are one command;
- builds never directly modify active runtime configuration;
- installation remains backed up, constrained, verifiable, and reversible;
- multi-runtime orchestration is accurate about sequential, non-transactional behavior;
- the implementation remains small and understandable.

The product is not an enterprise deployment platform, transaction engine, hosted synchronization service, or autonomous-agent framework.

## 4. Target User

The primary user is an engineer who uses one or more AI coding runtimes and wants one durable, consistent instruction system across them without manually coordinating separate build and installation commands.

Contributors may also extend shared workflows, capabilities, tests, and runtime adapters. Multi-user administration and fleet management remain outside scope.

## 5. Product Goals

The product must:

1. Maintain shared agent behavior in runtime-neutral Markdown modules.
2. Generate native instruction files for supported runtimes.
3. Preserve the discovery, approval, implementation, safety, testing, and reporting lifecycle.
4. Produce deterministic, inspectable artifacts.
5. Verify source modules, generated output, and installed files.
6. Provide a first-time setup command.
7. Provide an ongoing synchronization command.
8. Detect supported runtimes from adapter-defined installation paths.
9. Install only detected runtimes.
10. Keep build and installation responsibilities separate internally.
11. Create hash-verified backups before replacing existing runtime files.
12. Verify installed hashes after deployment.
13. Roll back the current runtime when installation fails.
14. Reject unsafe install and restore destinations.
15. Keep low-level commands available for development and diagnostics.
16. Remain compatible with Windows PowerShell 5.1 and PowerShell 7.

## 6. Non-Goals

The product will not provide:

- automatic installation of Codex, Claude Code, or Gemini CLI applications;
- automatic creation of missing runtime directories;
- a graphical user interface;
- a hosted synchronization service;
- background updates, scheduled tasks, daemons, or services;
- automatic runtime restarts;
- runtime authentication or credential management;
- dynamic instruction injection into an already running session;
- enterprise deployment or fleet management;
- transactional multi-runtime installation;
- automatic Git stashing, resetting, cleaning, committing, branch switching, or conflict resolution;
- structured JSON operation logs;
- release signing or formal certification automation;
- a general-purpose autonomous-agent framework.

## 7. Design Principles

### One shared source of truth

Reusable behavior belongs in shared modules, not runtime-specific or installed files.

### Runtime-native delivery

Each runtime receives the filename, install path, and header it expects.

### Adapter-driven mechanics

Generated output, installation targets, approved roots, and detection directories derive from runtime adapters. High-level scripts must not maintain a second independent runtime path map.

### Generated artifacts are disposable

Generated files are committed for review and freshness checks but are never edited manually.

### High-level simplicity, low-level safety

Users interact with setup and sync. Those commands orchestrate the existing build, verification, backup, rollback, and installed-hash mechanisms rather than bypassing them.

### Verify before trust

Source, generated output, and installed targets must be independently verifiable.

### Accurate guarantees

Sequential orchestration must never be described as a cross-runtime transaction.

## 8. Core Architecture

```text
Shared modules
(core/ workflows/ capabilities/ memory/)
        ↓
Manifest + runtime adapters
(config/agent.json + adapters/*.json)
        ↓
Deterministic generated artifacts
(generated/<runtime>/<file>)
        ↓
Runtime detection
(parent of adapter installation.path)
        ↓
Sequential refresh workflow
Build → generated verification → preview → install → installed verification
        ↓
Restart guidance for changed runtimes
```

Active installed targets are deployed copies of generated artifacts and must not be edited manually.

## 9. Supported Runtime Targets

| Runtime | Adapter ID | Generated file | Installed target | Setup/sync status |
|---|---|---|---|---|
| Codex | `codex` | `generated/codex/AGENTS.md` | `%USERPROFILE%\.codex\AGENTS.md` | Detected, installed, verified |
| Claude Code | `claude` | `generated/claude/CLAUDE.md` | `%USERPROFILE%\.claude\CLAUDE.md` | Detected, installed, verified |
| Gemini CLI | `gemini` | `generated/gemini/GEMINI.md` | `%USERPROFILE%\.gemini\GEMINI.md` | Detected, installed, verified |
| Generic | `generic` | `generated/generic/SYSTEM_PROMPT.md` | No default target | Generated only; excluded from automatic setup/sync |

A supported runtime is detected when its adapter is enabled and installable, its resolved target is within an approved root, and the target file's parent runtime directory already exists. The instruction file itself may be absent.

## 10. Primary User Journeys

### First-time setup

1. Install and launch at least one supported runtime so its user-level directory exists.
2. Clone the repository.
3. Run `setup-agent-system.ps1`.
4. Review detected runtimes and installation plans.
5. Allow sequential refresh to complete.
6. Restart only runtimes reported as changed.

### Ongoing synchronization

1. Run `sync-agent-system.ps1` from the repository.
2. The command validates Git, branch, and working-tree state.
3. It runs `git pull --rebase origin main`.
4. It reloads configuration and detects supported runtime directories.
5. It refreshes detected runtimes sequentially.
6. It reports updated, already-current, skipped, failed, and restart-required runtimes.

### Developer synchronization

Use:

```powershell
.\scripts\sync-agent-system.ps1 -SkipPull
```

This uses the current checkout while preserving manifest, adapter, build, verification, and installation validation.

### Advanced targeted operation

Developers may still invoke build, verify, install, and restore commands for one runtime when diagnosing or testing a specific layer.

## 11. Functional Requirements

### FR-1: Shared module authoring

Agent behavior must be maintained in ordered runtime-neutral modules.

### FR-2: Deterministic generation

Unchanged source, configuration, and adapters must produce byte-equivalent artifacts.

### FR-3: Runtime adapters

Each runtime must define output, install path, approved roots, document title, and runtime header through an adapter.

### FR-4: Runtime detection

Setup and sync must detect Codex, Claude Code, and Gemini CLI from adapter-derived runtime directories and must not create missing directories.

### FR-5: First-time setup

`setup-agent-system.ps1` must validate configuration, detect supported runtimes, process only detected runtimes, and return a distinct non-zero exit when none are detected.

### FR-6: Ongoing synchronization

`sync-agent-system.ps1` must, by default, validate Git state, run `git pull --rebase origin main`, reload configuration, and refresh detected runtimes.

### FR-7: Git safety

Default sync must require Git, branch `main`, and a clean working tree including untracked files. It must not modify local work to satisfy those preconditions.

### FR-8: Developer override

`-SkipPull` must bypass pull-specific checks while preserving all non-Git validation and refresh behavior.

### FR-9: Preview and confirmation

High-level commands must support `-WhatIf`, `-Confirm`, and `-Force` consistently with documented PowerShell semantics.

### FR-10: Sequential orchestration

Detected runtimes must be processed in deterministic order: Codex, Claude Code, Gemini CLI. The workflow must stop on the first failure and report earlier success accurately.

### FR-11: Safe target validation

Installation and restore must reject targets outside approved roots and unsafe filesystem redirection such as reparse points.

### FR-12: Backup and rollback

Existing targets must be backed up and hash-verified before replacement. A failed current-runtime installation must restore or remove the affected target according to the existing installer contract.

### FR-13: Installed verification

After installation, the deployed runtime file must match the selected generated artifact.

### FR-14: Restart guidance

Final output should list only runtimes whose installed files changed.

### FR-15: Test isolation

Automated tests must use sandbox repositories and temporary target maps and must never modify real runtime configuration files.

### FR-16: Backward compatibility

Low-level build, verify, install, restore, and compatibility wrapper commands must remain available unless separately deprecated and approved.

## 12. Command Contracts

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

### Exit codes

| Exit code | Meaning |
|---|---|
| `0` | All intended operations succeeded; already-current files count as success |
| `1` | Validation, build, verification, installation, or unexpected failure |
| `2` | No supported runtime detected |
| `3` | Git precondition or pull failure |

## 13. Installation Semantics

The user-facing setup and sync commands may update multiple detected runtimes, but they do so one runtime at a time.

If Codex succeeds and Claude Code fails:

- Codex remains updated;
- Gemini CLI is not attempted;
- the final output must report the partial result accurately;
- there is no rollback of previously completed runtimes.

Transactional multi-runtime installation remains explicitly deferred.

## 14. Non-Functional Requirements

### Reliability

- deterministic builds;
- meaningful exit codes;
- fail-fast orchestration;
- installed hash verification;
- verified backups and rollback behavior;
- accurate partial-success reporting.

### Safety

- detection is read-only;
- missing runtime directories are never created automatically;
- previews do not pull or install;
- Git sync does not alter local work;
- targets remain constrained to approved runtime roots;
- tests never access production runtime paths.

### Maintainability

- adapters remain small and runtime-focused;
- detection and refresh logic are shared libraries;
- setup and sync do not duplicate runtime paths or workflow logic;
- low-level commands remain independently usable;
- documentation consistently distinguishes user-facing and advanced workflows.

### Compatibility

- Windows PowerShell 5.1 and PowerShell 7;
- no mandatory external test framework;
- fixed Git argument tokens rather than interpolated shell command strings.

## 15. Success Criteria

The streamlined workflow is complete when:

- first-time setup succeeds for any detected combination of Codex, Claude Code, and Gemini CLI;
- setup exits safely when no runtime directory exists;
- normal sync safely pulls `origin/main` and refreshes detected runtimes;
- dirty or wrong-branch working trees are rejected without modification;
- `-SkipPull`, `-WhatIf`, `-Force`, and `-Confirm` behave as documented;
- runtime detection derives from adapter metadata;
- changed runtimes receive restart guidance;
- automated tests use only temporary runtime targets;
- README, PRD, installation, operations, adapter, specification, and implementation documents describe the same product model.

## 16. Current Implementation Status

Implemented:

- shared runtime-neutral instruction modules;
- adapters for Codex, Claude Code, Gemini CLI, and Generic;
- deterministic build and verification tooling;
- approved-root installation, backups, rollback, restore, and installed-hash verification;
- adapter-driven runtime detection;
- shared refresh orchestration;
- `setup-agent-system.ps1`;
- `sync-agent-system.ps1` with Git safety and `-SkipPull`;
- setup/sync test coverage using sandbox repositories and temporary targets;
- compatibility low-level and runtime-specific commands.

The setup and sync commands are the recommended product entry points. Manual build/install commands remain advanced tools rather than the normal user journey.

## 17. Known Limitations

- Multi-runtime refresh is sequential and non-transactional.
- Runtime applications must be installed and launched separately.
- Missing runtime directories are not created automatically.
- Active runtime sessions are not restarted automatically.
- Git synchronization supports the approved `main` and `origin/main` workflow only.
- There is no background updater, hosted synchronization, dashboard, or enterprise deployment layer.

## 18. Deferred Ideas

- additional runtime adapters such as Copilot CLI, Cursor, Continue, Aider, and xAI;
- transactional multi-runtime installation;
- transaction journals and interrupted-operation recovery;
- structured operation records;
- backup retention management;
- `doctor`, `status`, and recovery dashboards;
- release signing and certification automation;
- hosted synchronization and enterprise administration.

Deferred items require separate discovery and approval.

## 19. Product Boundaries and Governance

- Shared modules are authoritative for reusable behavior.
- Runtime adapters are authoritative for delivery mechanics.
- Generated files are reviewable build artifacts.
- Installed files are deployed copies.
- Setup and sync do not install runtime applications.
- Installation does not imply approval to implement unrelated project work.
- Discovery, approval, implementation, verification, and durable context maintenance remain separate lifecycle stages.
