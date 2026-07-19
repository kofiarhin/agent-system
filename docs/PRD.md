# Universal Agent System — Product Requirements Document

**Status:** Implemented v1.0.0; MVP hardening proposed  
**Primary platform:** Windows with PowerShell 5.1 or later  
**Repository:** `kofiarhin/agent-system`

## 1. Executive Summary

Universal Agent System is a small, model-agnostic instruction system for AI coding runtimes. It keeps reusable agent behavior in one shared source and generates runtime-native instruction files for Codex, Claude Code, Gemini CLI, and generic/custom agents.

The MVP is intentionally narrow:

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
Explicit single-runtime installation
```

The product should generate instructions, install them safely, and stay out of the user's way. Every MVP feature must improve portability, safety, or maintainability.

## 2. Problem Statement

AI coding runtimes use different instruction filenames, locations, precedence rules, and configuration formats. Maintaining separate instruction systems causes behavior drift, repeated fixes, mixed runtime concerns, manually edited installed files, and unclear traceability.

Universal Agent System separates shared behavior from runtime delivery mechanics so the same approved instruction model can be generated consistently for multiple runtimes.

## 3. MVP Vision

Provide a dependable personal-use instruction system in which:

- shared behavior is authored once;
- each runtime receives a native instruction file;
- generated artifacts are deterministic and reviewable;
- builds never modify active runtime configuration;
- installation is explicit, backed up, and verifiable;
- restore is validated and reversible;
- adding a runtime does not require duplicating shared behavior;
- the implementation remains small and understandable.

The MVP is not an enterprise deployment platform, transaction engine, or autonomous-agent framework.

## 4. Target User

The primary user is an engineer who uses multiple AI coding runtimes and wants one durable, consistent instruction system across them.

Contributors may also add shared workflows, capabilities, or runtime adapters, but multi-user administration and hosted coordination are outside the MVP.

## 5. MVP Goals

The product must:

1. Maintain shared agent behavior in runtime-neutral Markdown modules.
2. Generate native instruction files for supported runtimes.
3. Preserve the established discovery, approval, implementation, safety, testing, and reporting lifecycle.
4. Produce deterministic, inspectable artifacts.
5. Verify source modules, generated output, and installed files.
6. Separate building from installation.
7. Install one runtime at a time as the recommended deployment workflow.
8. Create durable, hash-verified backups before replacing an existing runtime file.
9. Restore validated backups with rollback protection.
10. Reject unsafe install and restore destinations.
11. Run verification and tests on Windows CI.
12. Keep day-to-day maintenance understandable and scriptable.

## 6. MVP Non-Goals

The MVP will not provide:

- a graphical user interface;
- a hosted synchronization service;
- runtime authentication or credential management;
- dynamic instruction injection into a running session;
- enterprise deployment or fleet management;
- transactional multi-runtime installation;
- a transaction journal or recovery engine;
- structured JSON operation logs;
- `doctor`, `status`, or recovery dashboards;
- release signing or formal certification automation;
- automated requirements traceability tooling;
- a general-purpose autonomous agent framework.

These features may be reconsidered only when a real user need justifies their complexity.

## 7. Design Principles

### One shared source of truth

Reusable behavior belongs in shared modules, not runtime-specific files.

### Runtime-native delivery

Each runtime receives the filename and header it expects.

### Generated artifacts are disposable

Generated files are committed for review and freshness checks but are never edited manually.

### Build and install are separate

A build writes only to generated output. Installation requires an explicit command.

### Verify before trust

Source, generated files, and installed targets must be independently verifiable.

### Safe, reversible changes

Existing runtime files are backed up before replacement. Restore validates backup identity and integrity and protects the pre-restore target.

### Prefer simplicity

The MVP should use the smallest mechanism that satisfies its safety requirements. Complexity is deferred rather than anticipated.

## 8. Core Architecture

Shared behavior lives under:

```text
core/
workflows/
capabilities/
memory/
```

Runtime-specific delivery details live under:

```text
adapters/
```

`config/agent.json` defines enabled runtimes and the ordered modules used during generation.

Generated artifacts include:

```text
generated/codex/AGENTS.md
generated/claude/CLAUDE.md
generated/gemini/GEMINI.md
generated/generic/SYSTEM_PROMPT.md
```

Active installed targets are deployed copies of generated artifacts and must not be edited manually.

## 9. Supported Runtimes

| Runtime | Generated file | Default installed target | MVP status |
|---|---|---|---|
| Codex | `generated/codex/AGENTS.md` | `%USERPROFILE%\.codex\AGENTS.md` | Generated, installed, and verified |
| Claude Code | `generated/claude/CLAUDE.md` | `%USERPROFILE%\.claude\CLAUDE.md` | Generated, installed, and verified |
| Gemini CLI | `generated/gemini/GEMINI.md` | `%USERPROFILE%\.gemini\GEMINI.md` | Generated and verified; installation remains optional |
| Generic | `generated/generic/SYSTEM_PROMPT.md` | No default production target | Generated for custom use |

## 10. Primary User Journeys

### Install a runtime

1. Clone or update the repository.
2. Run source and generated verification.
3. Build the intended runtime.
4. Review the generated artifact.
5. Preview installation with `-WhatIf`.
6. Install one runtime.
7. Verify the installed target.
8. Restart and test the runtime.
9. Repeat separately for another runtime when needed.

### Change shared behavior

1. Edit shared source or configuration.
2. Build the affected runtime or all generated outputs.
3. Verify source and generated artifacts.
4. Review generated diffs.
5. Run tests.
6. Preview and install one runtime at a time.
7. Verify each installed target.
8. Commit source and generated changes together.

### Restore a previous file

1. List available backups.
2. Preview the selected restore.
3. Validate the backup manifest, hash, runtime, and original target identity.
4. Preserve the current target before replacement.
5. Restore the selected backup.
6. Verify the restored file.
7. Roll back automatically if restore replacement or verification fails.

## 11. Functional Requirements

### FR-1: Shared module authoring

Agent behavior must be maintained in ordered Markdown modules independent of runtime-specific home paths or filenames.

### FR-2: Deterministic generation

Unchanged source, configuration, and adapters must produce byte-equivalent generated artifacts.

### FR-3: Runtime adapters

Each supported runtime must define output file, install path, title, and runtime header through an adapter.

### FR-4: Source traceability

Generated artifacts must include a generated-file warning and source markers.

### FR-5: Build isolation

Build commands must write only to generated output locations.

### FR-6: Verification scopes

Verification must support source, generated, and installed scopes and return a non-zero exit code on failure.

### FR-7: Freshness detection

The system must detect generated artifacts that differ from a clean rebuild.

### FR-8: Installation preview

Users must be able to preview installation without changing files.

### FR-9: Safe target validation

Installation and restore must reject paths outside approved runtime roots and must defend against path traversal and unsafe filesystem redirection such as reparse points.

### FR-10: Durable backup creation

When a target exists, the installer must create and hash-verify a timestamped backup and persist its manifest before modifying the target.

### FR-11: Installed hash verification

After installation, the active runtime file must match the selected generated artifact.

### FR-12: Validated restore

Restore must validate manifest structure, runtime identity, original target identity, and backup hash before replacement.

### FR-13: Restore rollback

If restore replacement or post-restore verification fails, the previous target must be reinstated and verified.

### FR-14: Test isolation

Automated tests must operate in temporary directories and must never modify real runtime configuration files.

### FR-15: Accurate guarantees

Documentation must describe replacement and multi-runtime behavior conservatively. The MVP must not claim atomic or transactional guarantees that are not implemented and tested.

### FR-16: Windows CI

CI must run deterministic build checks, verification, and tests on supported Windows PowerShell environments.

## 12. Installation Semantics

The supported MVP deployment workflow is one runtime per install command.

`-Runtime All` may remain available for build and verification. Where installation still accepts `-Runtime All`, it is sequential and non-transactional: an earlier runtime may be updated before a later runtime fails. Documentation and command output must make this limitation clear.

Transactional multi-runtime installation is explicitly deferred.

## 13. MVP Hardening Backlog

The following work defines the approved MVP hardening direction:

1. Persist backup manifests before target modification.
2. Add verified rollback to restore operations.
3. Enforce restore destination identity from the backup manifest.
4. Harden runtime target validation, including reparse-point defenses.
5. Add strict backup manifest validation.
6. Correct documentation that overstates replacement atomicity.
7. Add Windows CI for build freshness, verification, and tests.
8. Add targeted failure-path tests for install, backup, replacement, and restore.
9. Keep installation operationally one runtime at a time; do not add a transaction engine for the MVP.

## 14. Non-Functional Requirements

### Reliability

- builds are deterministic;
- validation failures stop installation or restore;
- scripts return meaningful exit codes;
- installed files are hash-verified;
- corrupt backups are rejected;
- restore rollback is verified.

### Safety

- installation is explicit;
- previews do not write files;
- targets are constrained to approved runtime roots;
- backup metadata is durable before replacement;
- tests never access production runtime paths.

### Maintainability

- shared behavior remains modular;
- adapters remain small and runtime-focused;
- generated files retain source traceability;
- documentation distinguishes implemented guarantees from future ideas;
- new infrastructure is not added without a demonstrated need.

### Compatibility

- scripts support Windows PowerShell 5.1 and PowerShell 7;
- the repository remains usable without mandatory external test dependencies;
- runtime-specific differences do not leak into shared behavior unless unavoidable.

## 15. MVP Success Criteria

The MVP hardening release is complete when:

- repeated clean builds are deterministic;
- verification passes for all enabled adapters and modules;
- Codex and Claude Code can be installed safely one runtime at a time;
- an existing target is backed up and its manifest is durable before replacement;
- unsafe or mismatched restore destinations are rejected;
- failed restore operations reinstate and verify the pre-restore target;
- Windows CI passes on the supported PowerShell versions;
- targeted failure-path tests pass;
- documentation accurately describes sequential, non-transactional multi-runtime behavior;
- a new contributor can complete installation and recovery using the documentation.

The intended quality target is a polished, maintainable MVP rather than maximum enterprise-grade complexity.

## 16. Current Implementation Status

Version 1.0.0 includes:

- shared runtime-neutral modules;
- adapters for Codex, Claude Code, Gemini CLI, and Generic;
- deterministic PowerShell build tooling;
- source, generated, installed, and behavioral-anchor verification;
- timestamped SHA-256-verified backups;
- installation and restore scripts with approved-path checks and `-WhatIf` support;
- a Pester-independent test suite;
- product, installation, operations, adapter, and migration documentation.

Codex and Claude Code have been installed and verified. Gemini output is generated and verified, while production installation remains optional.

The MVP hardening backlog remains proposed until approved and implemented work is verified.

## 17. Known Limitations

Until the hardening backlog is complete:

- backup manifest durability during partial failure needs strengthening;
- restore rollback is not yet fully verified;
- restore target identity validation needs strengthening;
- filesystem-aware path validation needs reparse-point protection;
- replacement should not be described as atomic;
- multi-runtime installation is sequential and not transactional;
- Windows CI coverage needs to be added.

Install and verify one runtime at a time.

## 18. Deferred Post-MVP Ideas

The following are intentionally deferred:

- transactional multi-runtime installation;
- transaction journals and interrupted-operation recovery;
- structured operation records;
- backup retention management;
- `doctor`, `status`, or recovery commands;
- native Windows replacement APIs;
- formal threat-model tooling;
- release signing and certification automation;
- requirements traceability automation;
- hosted synchronization or enterprise administration.

Deferred items are not commitments. They require separate discovery and approval.

## 19. Product Boundaries and Governance

- Shared modules are authoritative for reusable behavior.
- Runtime files are generated deployment artifacts.
- Project-level repository instructions remain authoritative within their own scope according to runtime precedence rules.
- Installation does not imply approval to implement project work.
- Discovery, approval, implementation, verification, and durable context maintenance remain separate lifecycle stages.
- Security-sensitive changes require explicit review and approval.

## 20. Related Documentation

- [Installation Guide](INSTALLATION.md)
- [Operations Guide](OPERATIONS.md)
- [Runtime Adapter Guide](RUNTIME_ADAPTER_GUIDE.md)
- [Migration Report](MIGRATION_REPORT.md)
