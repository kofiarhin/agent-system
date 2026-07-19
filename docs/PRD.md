# Universal Agent System — Product Requirements Document

**Status:** Implemented v1.0.0  
**Primary platform:** Windows with PowerShell 5.1 or later  
**Repository:** `kofiarhin/agent-system`

## 1. Executive Summary

The Universal Agent System is a model-agnostic instruction architecture for AI coding runtimes. It provides one shared source of truth for agent behavior and compiles that behavior into runtime-native instruction files for Codex, Claude Code, Gemini CLI, and generic/custom agents.

The product replaces separately maintained instruction files with a controlled pipeline:

```text
Shared instruction modules
        ↓
Configuration + runtime adapter
        ↓
Deterministic build
        ↓
Generated runtime artifact
        ↓
Verification
        ↓
Explicit installation
```

The result is a consistent engineering workflow across runtimes without duplicating policy, behavior, safety rules, or maintenance effort.

## 2. Problem Statement

AI coding runtimes commonly use different instruction filenames, locations, precedence rules, and configuration formats. Maintaining separate instruction systems for each runtime creates several problems:

- behavior drifts between runtimes;
- fixes must be repeated in multiple files;
- runtime-specific details become mixed with reusable engineering policy;
- installed files are edited manually and lose traceability;
- teams cannot reliably determine which instructions are current;
- migration to a new runtime requires rebuilding the instruction system from scratch.

The Universal Agent System solves these problems by separating shared agent behavior from runtime delivery mechanics.

## 3. Vision

Provide a dependable, portable agent instruction platform in which:

- shared behavior is authored once;
- each runtime receives a native instruction file;
- generated artifacts are deterministic and reviewable;
- installation is explicit and reversible;
- verification detects stale, invalid, or drifted instructions;
- adding a runtime does not require duplicating shared behavior.

The longer-term direction is an Agent OS architecture with reusable kernels, profiles, workflows, memory, plugins, compilers, and thin runtime adapters.

## 4. Target Users

### Primary user

An engineer who uses multiple AI coding runtimes and wants one durable, consistent instruction system across them.

### Secondary users

- teams standardizing agent-assisted engineering practices;
- maintainers supporting several runtime targets;
- contributors adding new workflows, capabilities, or runtime adapters;
- users migrating from a single-runtime instruction file to a shared system.

## 5. Goals

The product must:

1. Maintain shared agent behavior in runtime-neutral modules.
2. Generate native instruction files for supported runtimes.
3. Preserve the established discovery, approval, implementation, safety, testing, and reporting lifecycle.
4. Produce deterministic, inspectable artifacts.
5. Verify source modules, generated output, and installed files.
6. Separate building from installation.
7. Back up replaced runtime files before installation.
8. Support restoration from validated backups.
9. Make runtime expansion adapter-driven.
10. Keep day-to-day maintenance understandable and scriptable.

## 6. Non-Goals

Version 1 is not intended to:

- provide a graphical user interface;
- dynamically inject instructions into a running agent session;
- synchronize through a hosted service;
- manage model credentials or runtime authentication;
- replace runtime-native project instructions;
- provide complete cross-runtime transactional deployment guarantees;
- act as a general-purpose autonomous agent framework;
- automatically approve implementation work or bypass project-specific controls.

## 7. Design Principles

### One shared source of truth

Reusable behavior belongs in shared modules, not in runtime-specific files.

### Runtime-native delivery

Each runtime receives the filename and header it expects rather than depending on a universal loader.

### Generated artifacts are disposable

Generated files are build outputs. They are committed for review and freshness checks but are never edited manually.

### Build and install are separate

A build may generate files but must not change active runtime configuration. Installation requires an explicit command.

### Verification before trust

Source, generated files, and installed targets must be independently verifiable.

### Safe, reversible changes

Existing runtime files are backed up before replacement, and restore tooling validates hashes before use.

### Minimal runtime coupling

Adapters contain runtime mechanics only: identity, output path, install path, title, and runtime-specific header.

## 8. Core Concepts

### Model

The model is the shared behavior of the agent: request classification, discovery, approval gates, implementation discipline, testing, reporting, safety, and durable preferences.

The model lives primarily under:

```text
core/
workflows/
capabilities/
memory/
```

### Runtime

A runtime is a delivery target such as Codex, Claude Code, Gemini CLI, or a generic system prompt.

Runtime-specific details live under:

```text
adapters/
```

### Manifest

`config/agent.json` defines enabled runtimes and the ordered shared modules used during compilation.

### Generated artifact

A generated artifact is the runtime-native instruction file produced by the build process, for example:

```text
generated/codex/AGENTS.md
generated/claude/CLAUDE.md
generated/gemini/GEMINI.md
generated/generic/SYSTEM_PROMPT.md
```

### Installed target

The installed target is the active runtime file in the user's configuration directory. It is a deployed copy of a generated artifact and must not be edited manually.

## 9. Supported Runtimes

Version 1 supports:

| Runtime | Generated file | Default installed target | Status |
|---|---|---|---|
| Codex | `generated/codex/AGENTS.md` | `%USERPROFILE%\.codex\AGENTS.md` | Generated, installed, and verified |
| Claude Code | `generated/claude/CLAUDE.md` | `%USERPROFILE%\.claude\CLAUDE.md` | Generated, installed, and verified |
| Gemini CLI | `generated/gemini/GEMINI.md` | `%USERPROFILE%\.gemini\GEMINI.md` | Generated and verified; production install not yet confirmed |
| Generic | `generated/generic/SYSTEM_PROMPT.md` | No default production target | Generated for custom use |

## 10. High-Level Architecture

```text
┌────────────────────────────────────────────────────────────┐
│ Shared source                                                │
│ core/  workflows/  capabilities/  memory/                   │
└───────────────────────────┬────────────────────────────────┘
                            │ ordered by
                            ▼
┌────────────────────────────────────────────────────────────┐
│ config/agent.json + adapters/<runtime>.json                  │
└───────────────────────────┬────────────────────────────────┘
                            │ compiled by
                            ▼
┌────────────────────────────────────────────────────────────┐
│ scripts/build-agent.ps1                                     │
└───────────────────────────┬────────────────────────────────┘
                            │ writes
                            ▼
┌────────────────────────────────────────────────────────────┐
│ generated/<runtime>/<native-file>                           │
└───────────────────────────┬────────────────────────────────┘
                            │ validated by
                            ▼
┌────────────────────────────────────────────────────────────┐
│ scripts/verify-agent.ps1                                    │
└───────────────────────────┬────────────────────────────────┘
                            │ explicitly deployed by
                            ▼
┌────────────────────────────────────────────────────────────┐
│ scripts/install-agent.ps1                                   │
│ backup → replace → hash verification                        │
└────────────────────────────────────────────────────────────┘
```

## 11. Primary User Journeys

### Install an existing release

1. Clone the repository.
2. Confirm prerequisites.
3. Run source and generated verification.
4. Review the generated file for the intended runtime.
5. Preview installation with `-WhatIf`.
6. Install one runtime.
7. Verify the installed target.
8. Restart the runtime session.

### Change shared behavior

1. Edit a shared module or configuration file.
2. Build the affected runtime or all runtimes.
3. Verify source and generated artifacts.
4. Review generated diffs.
5. Run tests.
6. Preview installation.
7. Install each intended runtime.
8. Verify installed files.
9. Commit source and generated changes together.

### Add a runtime

1. Define a runtime adapter.
2. Add it to configuration.
3. Generate its native artifact.
4. Validate the artifact and adapter.
5. Add runtime-specific tests and documentation.
6. Install only after review and approval.

### Restore a previous file

1. List available backups.
2. Preview the selected restore.
3. Restore a specific runtime or backup set.
4. Verify the restored target.
5. Restart the affected runtime session.

## 12. Functional Requirements

### FR-1: Shared module authoring

The system must allow agent behavior to be maintained in ordered Markdown modules independent of runtime-specific home paths or filenames.

### FR-2: Deterministic generation

Given unchanged source modules, configuration, and adapters, repeated builds must produce byte-equivalent generated artifacts.

### FR-3: Runtime adapters

Each supported runtime must define its output file, install path, title, and runtime-specific header through an adapter rather than duplicated build logic.

### FR-4: Source markers

Generated artifacts must preserve traceability to their source modules through generated warnings and source markers.

### FR-5: Build isolation

The build process must write only to generated output locations and must never install active runtime files.

### FR-6: Verification scopes

Verification must support source, generated, and installed scopes and return a non-zero exit code on failure.

### FR-7: Freshness detection

The system must detect when committed generated artifacts do not match a clean rebuild from current source.

### FR-8: Installation preview

Users must be able to preview intended installation actions without changing files.

### FR-9: Approved target validation

Installation and restore operations must reject destinations outside approved runtime roots.

### FR-10: Backup creation

When an installed target already exists, the installer must create and hash-verify a timestamped backup before replacement.

### FR-11: Installed hash verification

After installation, the active runtime file must match the selected generated artifact.

### FR-12: Restore

Users must be able to list backups and restore a validated backup to an approved target.

### FR-13: Test isolation

Automated tests must operate in temporary directories and must not modify real runtime configuration files.

### FR-14: Manual edit prevention

Documentation and generated-file headers must clearly state that generated and installed files are not source files.

## 13. Non-Functional Requirements

### Reliability

- builds must be deterministic;
- validation failures must stop deployment;
- scripts must return meaningful exit codes;
- installed files must be hash-verified;
- backup corruption must be detected before restore.

### Safety

- installation must be explicit;
- previews must not write files;
- runtime targets must be constrained to approved roots;
- existing files must be backed up before replacement;
- tests must not access production runtime paths.

### Maintainability

- shared behavior must remain modular;
- adapters must stay small and runtime-focused;
- generated files must retain source traceability;
- documentation must distinguish product concepts, installation, and operations.

### Compatibility

- scripts must support Windows PowerShell 5.1 and PowerShell 7;
- the repository must remain usable without Pester or other external test dependencies;
- runtime-specific differences must not leak into shared behavior unless unavoidable.

### Observability

Build, verify, install, and restore commands should clearly report selected runtimes, source and target paths, backup creation, validation results, and failures.

## 14. Success Criteria

Version 1 is successful when:

- one source change can regenerate all supported runtime artifacts;
- a clean rebuild produces no unexpected diff;
- verification passes for all enabled adapters and modules;
- Codex and Claude Code can consume installed generated artifacts successfully;
- existing runtime files are preserved through verified backups;
- users can restore a prior file using documented commands;
- a new contributor can understand the system and complete an installation using repository documentation;
- no runtime-specific behavior needs to be duplicated across shared modules.

## 15. Current Implementation Status

Version 1.0.0 is implemented with:

- shared runtime-neutral modules;
- adapters for Codex, Claude Code, Gemini CLI, and Generic;
- deterministic PowerShell build tooling;
- source, generated, installed, and behavioral-anchor verification;
- timestamped SHA-256-verified backups;
- installation and restore scripts with approved-path checks and `-WhatIf` support;
- a Pester-independent test suite;
- migration, operations, adapter, and installation documentation.

Codex and Claude Code have been installed from generated artifacts and verified. Gemini has generated and verified output but has not yet been confirmed as installed in production.

## 16. Known Limitations

The deployment layer has known hardening opportunities:

- multi-runtime installation does not yet provide a fully durable all-or-nothing transaction across every runtime;
- backup manifest durability during partial multi-runtime failure should be strengthened;
- failed restore replacement should automatically reinstate the pre-restore target with verified rollback;
- temporary-file replacement guarantees should be described conservatively until stronger atomicity is proven;
- restore should verify that the manifest's original path matches the current adapter target;
- approved-root validation should be hardened for reparse points in parent paths;
- Windows CI should enforce build freshness, verification, and tests.

Until these items are resolved, production installation should be performed one runtime at a time and verified after each install.

## 17. Roadmap

### Near term: deployment hardening

- strengthen backup manifest durability;
- define or implement multi-runtime transaction semantics;
- add verified rollback for failed restore operations;
- harden target validation;
- qualify or improve replacement atomicity;
- add Windows GitHub Actions verification;
- re-audit installation and restore safety.

### Medium term: extensibility

- runtime profiles and capability bundles;
- additional adapters for Cursor, OpenCode, and custom agents;
- formal JSON Schema validation alongside manual security checks;
- packaged releases and versioned generated artifacts;
- clearer upgrade and compatibility policy.

### Long term: Agent OS

Potential future architecture:

```text
kernel/
memory/
workflows/
compiler/
plugins/
profiles/
runtimes/
```

In that architecture, runtimes remain thin delivery adapters while the shared kernel, workflows, profiles, and memory become independently reusable components.

## 18. Product Boundaries and Governance

- Shared modules are authoritative for reusable behavior.
- Runtime files are generated deployment artifacts.
- Project-level repository instructions remain authoritative within their own scope according to each runtime's precedence model.
- Installation does not imply approval to implement project work.
- Discovery, approval, implementation, verification, and durable context maintenance remain separate lifecycle stages.
- Security-sensitive changes require explicit review and approval.

## 19. Related Documentation

- [Installation Guide](INSTALLATION.md)
- [Operations Guide](OPERATIONS.md)
- [Runtime Adapter Guide](RUNTIME_ADAPTER_GUIDE.md)
- [Migration Report](MIGRATION_REPORT.md)
