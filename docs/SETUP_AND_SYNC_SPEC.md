# Streamlined Setup and Sync Specification

**Status:** Approved for implementation planning  
**Target:** Post-v1.0.1 user-experience improvement  
**Supported runtimes:** Codex, Claude Code, Gemini CLI  
**Primary platform:** Windows PowerShell 5.1 and PowerShell 7

## 1. Summary

The Agent System currently requires users to understand several separate operations: pull repository changes, build generated runtime files, verify them, install them, verify installed copies, and restart the affected runtime applications.

This specification introduces two high-level commands:

```powershell
.\scripts\setup-agent-system.ps1
.\scripts\sync-agent-system.ps1
```

`setup-agent-system.ps1` provides first-time installation from an already cloned repository. `sync-agent-system.ps1` provides ongoing one-command updates by pulling the latest repository changes and then refreshing every supported runtime detected on the local machine.

Both commands orchestrate existing build, verification, and installation primitives. They do not replace the underlying safety model and do not introduce cross-runtime transactions.

## 2. Problem Statement

The current user update path is:

```powershell
git pull --rebase origin main
.\scripts\update-all-agents.ps1
```

The combined wrapper is hard-coded to Codex and Claude Code. Gemini CLI already has an enabled adapter and install path, but is not included in the combined convenience workflow.

The current flow has four usability problems:

1. Users must remember multiple commands.
2. Users must know which runtime wrappers apply to their machine.
3. The combined wrapper attempts a fixed runtime list rather than detecting installed runtimes.
4. First-time setup and ongoing synchronization are not represented as distinct product workflows.

## 3. Goals

The implementation must:

- provide one first-time setup command;
- provide one ongoing synchronization command;
- automatically detect Codex, Claude Code, and Gemini CLI from their configured runtime directories;
- install only detected runtimes;
- automatically run `git pull --rebase origin main` during normal synchronization;
- provide `-SkipPull` for developers who want to use the current local checkout;
- reuse adapter metadata as the source of truth for output and installation paths;
- reuse existing build, verification, installation, backup, rollback, and installed-hash verification behavior;
- remain sequential and fail fast;
- clearly report detected, skipped, updated, failed, and restart-required runtimes;
- remain compatible with Windows PowerShell 5.1 and PowerShell 7.

## 4. Non-Goals

This work will not:

- add GitHub Actions continuous integration;
- automatically install Codex, Claude Code, or Gemini CLI applications;
- create runtime directories when no supported runtime is detected;
- support Cursor, Copilot, Aider, Continue, xAI, or generic/custom runtimes;
- introduce a background updater, scheduled task, daemon, service, or automatic restart;
- provide cross-runtime atomicity or rollback all previously completed runtime updates when a later runtime fails;
- replace the existing low-level build, verify, install, restore, or runtime-specific commands;
- perform package-manager installation or repository cloning in the initial implementation;
- silently discard, stash, commit, or overwrite local Git changes.

## 5. Supported Runtime Contract

The MVP supports exactly these enabled adapters:

| Runtime | Adapter ID | Detection directory | Installed file |
| --- | --- | --- | --- |
| Codex | `codex` | `%USERPROFILE%\.codex` | `%USERPROFILE%\.codex\AGENTS.md` |
| Claude Code | `claude` | `%USERPROFILE%\.claude` | `%USERPROFILE%\.claude\CLAUDE.md` |
| Gemini CLI | `gemini` | `%USERPROFILE%\.gemini` | `%USERPROFILE%\.gemini\GEMINI.md` |

The detection directory must be derived from the parent directory of the adapter's configured `installation.path`. The orchestration scripts must not maintain a second independent map of runtime paths.

A runtime is considered detected when:

1. its adapter is enabled;
2. installation is supported by the adapter;
3. the resolved installation path is valid under an approved root; and
4. the resolved parent runtime directory already exists.

The instruction file itself does not need to exist. This allows first-time Agent System installation into an already initialized runtime directory.

## 6. User Workflows

### 6.1 First-Time Setup

From an already cloned repository:

```powershell
.\scripts\setup-agent-system.ps1
```

The script must:

1. resolve and validate the repository root;
2. load and validate the agent manifest and supported runtime adapters;
3. detect supported runtime directories;
4. stop without writing when no supported runtime is detected;
5. display the detected installation plan;
6. build generated outputs for detected runtimes;
7. strictly verify generated outputs;
8. preview installation for each detected runtime;
9. install each detected runtime sequentially;
10. verify each installed artifact;
11. print a final summary and restart guidance.

Setup does not run `git pull`. Its purpose is to install the current checked-out version after cloning or local preparation.

### 6.2 Ongoing Synchronization

```powershell
.\scripts\sync-agent-system.ps1
```

The script must:

1. resolve and validate the repository root;
2. run pre-pull Git safety checks;
3. execute `git pull --rebase origin main`;
4. stop if the pull fails;
5. reload repository configuration after the pull;
6. detect supported runtime directories;
7. stop without installation when none are detected;
8. build, verify, preview, install, and verify each detected runtime sequentially;
9. print a final summary and restart guidance.

Developer override:

```powershell
.\scripts\sync-agent-system.ps1 -SkipPull
```

With `-SkipPull`, synchronization uses the current working tree and does not invoke Git.

## 7. Git Safety Requirements

Before the default sync pull, the script must:

- confirm that `git` is available;
- confirm that the repository is a Git working tree;
- confirm that the current branch is `main` unless an explicit future override is approved;
- detect uncommitted tracked or untracked changes;
- refuse to pull when the working tree is not clean;
- display a clear remediation message rather than modifying local work;
- execute the pull as an external process and validate its exit code;
- stop immediately if the pull fails or reports a rebase conflict.

The script must not automatically stash, reset, clean, commit, switch branches, or resolve conflicts.

`-SkipPull` bypasses these pull-specific checks but does not bypass repository, manifest, adapter, build, verification, or installation validation.

## 8. Runtime Detection Design

Add a shared detection function to the PowerShell library layer rather than implementing detection separately in setup and sync.

Suggested interface:

```powershell
Get-DetectedAgentRuntimes -RepoRoot $repoRoot -RuntimeIds @('codex', 'claude', 'gemini')
```

Each result should include:

```text
RuntimeId
DisplayName
AdapterPath
GeneratedPath
InstallPath
DetectionDirectory
Detected
Reason
```

Expected reasons include:

- `Detected`
- `AdapterDisabled`
- `InstallationUnsupported`
- `RuntimeDirectoryMissing`
- `InvalidInstallPath`

Detection is read-only. It must not create directories or files.

## 9. Orchestration Design

The setup and sync scripts should share a common orchestration function to avoid workflow drift.

Suggested internal function:

```powershell
Invoke-AgentSystemRefresh `
    -RepoRoot $repoRoot `
    -RuntimeIds $detectedRuntimeIds `
    -Mode Setup
```

For each detected runtime, the orchestrator must invoke the existing primitives in this order:

```text
Build
Verify generated output
Preview installation
Install
Verify installed artifact
```

The implementation may call existing scripts as child processes or extract reusable functions, but must preserve their current validation and exit-code behavior.

Runtime processing order is deterministic:

1. Codex
2. Claude Code
3. Gemini CLI

The workflow is sequential and fail-fast. If Claude fails after Codex succeeds, Codex remains updated and Gemini is not attempted. The final output must state this accurately.

## 10. Command Interfaces

### 10.1 `setup-agent-system.ps1`

Initial parameters:

```powershell
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Force
)
```

Behavior:

- `-WhatIf` shows detection, build/install intent, and target paths without installing;
- `-Confirm` follows PowerShell confirmation semantics for write operations;
- `-Force` forwards reinstall intent to the existing installer when installed files already match.

### 10.2 `sync-agent-system.ps1`

Initial parameters:

```powershell
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SkipPull,
    [switch]$Force
)
```

Behavior:

- default: pull, then refresh detected runtimes;
- `-SkipPull`: skip Git update and refresh from current local source;
- `-Force`: reinstall matching runtime files;
- `-WhatIf`: must not pull or install; it displays the actions that would occur;
- `-Confirm`: applies to mutating actions.

No `-Runtime` selector is required in the first implementation. The product promise is automatic detection. Existing low-level scripts remain available for targeted runtime operations.

## 11. Output and User Experience

### 11.1 Detection Output

```text
==> Detect supported runtimes

Runtime       Directory                  Status
Codex         C:\Users\Kofi\.codex       Detected
Claude Code   C:\Users\Kofi\.claude      Detected
Gemini CLI    C:\Users\Kofi\.gemini      Not found
```

### 11.2 Successful Sync Output

```text
==> Pull latest Agent System changes
OK  Repository updated from origin/main.

==> Refresh detected runtimes
OK  Codex installed and verified.
OK  Claude Code already current.

Summary
Codex        Updated
Claude Code  Already current
Gemini CLI   Not detected

Restart Codex. Claude Code does not require a restart when no file changed.
```

Restart guidance should list only runtimes whose installed file changed. If conservative runtime behavior requires always restarting detected runtimes, documentation must say so consistently; the preferred behavior is changed-runtime-only guidance.

### 11.3 No Runtime Detected

```text
No supported runtime directories were detected.

Install and launch at least one supported runtime first:
- Codex
- Claude Code
- Gemini CLI

The Agent System did not create runtime folders or install any files.
```

Exit code should be non-zero because the requested setup or sync could not update any runtime.

## 12. Exit Codes

The scripts should use stable categories:

| Exit code | Meaning |
| --- | --- |
| `0` | All intended operations succeeded; already-current files are success |
| `1` | General validation, build, verification, installation, or unexpected failure |
| `2` | No supported runtime detected |
| `3` | Git precondition or pull failure |

Child-script non-zero exits must be propagated or normalized into the documented category without masking the underlying message.

## 13. Security and Safety Requirements

The high-level workflows must preserve all existing protections:

- generated artifacts are verified before installation;
- install paths come from validated adapters;
- targets remain within approved runtime roots;
- existing files are backed up before replacement;
- installed hashes are verified;
- failed single-runtime installation attempts use existing rollback behavior;
- tests use temporary target maps and never access real user runtime directories;
- detection never interprets arbitrary repository content as an executable path;
- Git commands use fixed arguments rather than interpolated shell strings.

This feature does not strengthen or weaken the approved v1.0.1 safety-hardening requirements. Where implementation depends on v1.0.1 changes, v1.0.1 must land first or the implementation must be rebased onto the verified hardened primitives.

## 14. Backward Compatibility

The following commands remain supported:

```powershell
.\scripts\build-agent.ps1
.\scripts\verify-agent.ps1
.\scripts\install-agent.ps1
.\scripts\restore-agent.ps1
.\scripts\update-codex-agent.ps1
.\scripts\update-claude-agent.ps1
.\scripts\update-all-agents.ps1
```

The new setup and sync commands become the recommended user-facing entry points. Existing wrappers may later be marked as advanced or compatibility commands, but must not be removed in this change.

## 15. Documentation Requirements

Implementation must update:

- `README.md` quick start;
- `docs/INSTALLATION.md` first-time setup;
- `docs/OPERATIONS.md` ongoing synchronization and developer overrides;
- command help blocks in both new scripts;
- troubleshooting for dirty working trees, missing Git, detached/wrong branches, pull conflicts, no detected runtimes, build failures, and installation failures.

Documentation must explicitly distinguish:

- repository synchronization from GitHub Actions CI;
- runtime application installation from Agent System instruction installation;
- sequential orchestration from cross-runtime transactions.

## 16. Testing Requirements

Tests must cover PowerShell 5.1 and PowerShell 7 compatible behavior without using real runtime folders.

Required scenarios:

### Detection

- all three runtime directories detected;
- one runtime detected;
- none detected;
- adapter disabled;
- installation unsupported;
- invalid or escaped install path rejected;
- instruction file absent but parent runtime directory present;
- deterministic runtime order.

### Setup

- builds and installs all detected runtimes;
- skips non-detected runtimes;
- no detected runtime exits with code `2` and writes nothing;
- child build failure stops before installation;
- first runtime installation failure stops later runtimes;
- already-current installation succeeds;
- `-Force` is forwarded;
- `-WhatIf` creates no runtime files.

### Sync and Git

- clean `main` checkout pulls before build;
- `-SkipPull` does not invoke Git;
- missing Git exits with code `3`;
- non-repository directory exits with code `3`;
- dirty working tree exits with code `3` without stashing or resetting;
- wrong branch exits with code `3`;
- pull failure exits with code `3` and prevents build/install;
- `-WhatIf` does not invoke pull;
- configuration is reloaded after a successful pull.

### Reporting

- changed runtimes appear in restart guidance;
- non-detected runtimes appear as not detected;
- partial sequential success is accurately reported;
- failure output includes the failing phase and runtime.

## 17. Acceptance Criteria

The feature is complete when:

1. A new user with an already cloned repository and at least one initialized supported runtime can run one setup command.
2. An existing user with a clean `main` checkout can run one sync command that pulls and refreshes every detected supported runtime.
3. Codex, Claude Code, and Gemini CLI are detected from adapter-derived runtime directories.
4. Missing runtime directories are never created by detection.
5. No-runtime detection stops safely with clear instructions.
6. Dirty working trees are never automatically modified.
7. Existing build, verification, installation, backup, rollback, and installed-hash verification protections remain active.
8. Runtime updates are deterministic, sequential, and fail-fast.
9. Partial success is reported honestly and no cross-runtime transactional guarantee is claimed.
10. PowerShell 5.1 and PowerShell 7 tests pass without touching real runtime directories.
11. README, installation, operations, and command help documentation match implemented behavior.
12. Existing low-level and runtime-specific commands continue to work.

## 18. Future Extensions

Potential later work, outside this specification:

- bootstrap command that clones the repository;
- package-manager installation;
- opt-in runtime selector;
- GitHub Copilot CLI adapter;
- cross-platform shell entry points;
- scheduled update checks;
- signed releases and version channels;
- runtime health/status command.
