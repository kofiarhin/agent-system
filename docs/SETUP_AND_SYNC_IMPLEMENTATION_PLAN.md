# Streamlined Setup and Sync Implementation Plan

**Related specification:** [`SETUP_AND_SYNC_SPEC.md`](SETUP_AND_SYNC_SPEC.md)  
**Delivery model:** Direct implementation on `main` only when explicitly authorized  
**Current status:** Planning complete; implementation not started

## 1. Objective

Implement two user-facing PowerShell entry points:

```powershell
.\scripts\setup-agent-system.ps1
.\scripts\sync-agent-system.ps1
```

The first installs the Agent System into detected Codex, Claude Code, and Gemini CLI runtime directories from the current checkout. The second performs a safe pull from `origin/main` and refreshes the same detected runtimes.

The implementation must reuse the repository's existing adapter, build, verification, installation, backup, rollback, and installed-artifact verification behavior.

## 2. Delivery Constraints

- Complete or rebase onto the approved v1.0.1 safety-hardening work before release.
- Preserve one-runtime-at-a-time installation internally.
- Preserve sequential fail-fast orchestration.
- Do not claim cross-runtime transactionality.
- Do not access real user runtime directories in automated tests.
- Maintain compatibility with Windows PowerShell 5.1 and PowerShell 7.
- Avoid unrelated refactoring.
- Keep existing low-level and compatibility wrappers working.

## 3. Proposed File Changes

### New files

```text
scripts/setup-agent-system.ps1
scripts/sync-agent-system.ps1
scripts/lib/RuntimeDetection.ps1
scripts/lib/RefreshWorkflow.ps1
tests/runtime-detection.tests.ps1
tests/setup-agent-system.tests.ps1
tests/sync-agent-system.tests.ps1
```

The exact test filenames may follow existing repository naming conventions discovered during implementation.

### Existing files likely to change

```text
scripts/lib/Common.ps1
scripts/lib/Configuration.ps1
scripts/install-agent.ps1
scripts/verify-agent.ps1
README.md
docs/INSTALLATION.md
docs/OPERATIONS.md
docs/PRD.md
tests/run-tests.ps1
```

`install-agent.ps1` and `verify-agent.ps1` should change only when a small, necessary interface improvement is required to expose structured results or support safe orchestration. Prefer wrapping existing commands over broad extraction.

## 4. Architecture

### 4.1 Runtime Detection Layer

Add `scripts/lib/RuntimeDetection.ps1` with read-only functions.

Primary function:

```powershell
Get-DetectedAgentRuntimes
```

Responsibilities:

1. accept repository root and an ordered allowlist of runtime IDs;
2. import each adapter through existing configuration helpers;
3. confirm the adapter is enabled and installable;
4. resolve the adapter installation path and approved roots;
5. validate the path before inspecting the filesystem;
6. derive the detection directory from the target file's parent directory;
7. test whether that directory exists;
8. return structured detection records for detected and non-detected runtimes.

Do not create directories. Do not infer runtime installation from command availability in the first version. Directory existence is the approved signal.

Suggested record:

```powershell
[pscustomobject]@{
    RuntimeId         = 'codex'
    DisplayName       = 'Codex'
    InstallPath       = 'C:\Users\...\.codex\AGENTS.md'
    DetectionDirectory= 'C:\Users\...\.codex'
    GeneratedPath     = '...\generated\codex\AGENTS.md'
    Detected          = $true
    Reason            = 'Detected'
}
```

### 4.2 Shared Refresh Workflow

Add `scripts/lib/RefreshWorkflow.ps1`.

Primary function:

```powershell
Invoke-AgentSystemRefresh
```

Responsibilities:

1. accept ordered detected runtime records;
2. run build and strict generated verification;
3. preview install for each runtime;
4. install each runtime sequentially;
5. verify installed output after each install;
6. collect structured per-runtime outcomes;
7. stop on the first failure;
8. return enough information for restart guidance and partial-success reporting.

Prefer invoking the current scripts with explicit runtime IDs:

```powershell
build-agent.ps1 -Runtime <id>
verify-agent.ps1 -Scope Generated -Runtime <id> -Strict
install-agent.ps1 -Runtime <id>
verify-agent.ps1 -Scope Installed -Runtime <id> -Strict
```

During implementation, confirm the actual `verify-agent.ps1` parameter surface. Adjust to the existing supported interface rather than inventing incompatible arguments.

### 4.3 Git Synchronization Layer

Implement Git-specific helpers in `sync-agent-system.ps1` or a small shared library if tests show that isolation materially improves maintainability.

Required helper responsibilities:

- locate `git` with `Get-Command`;
- confirm the repository root is a work tree;
- read the current branch;
- inspect porcelain status including untracked files;
- invoke `git pull --rebase origin main` with fixed argument tokens;
- capture exit code and output;
- distinguish precondition failure from pull failure;
- avoid command-string interpolation and `Invoke-Expression`.

Suggested functions:

```powershell
Test-AgentRepositoryReadyForPull
Invoke-AgentRepositoryPull
```

## 5. Implementation Phases

## Phase 0 — Revalidate Repository State

Before code changes:

1. pull current `main`;
2. confirm the working tree is clean;
3. read current `AGENTS.md` or repository instructions;
4. re-read the PRD, installation guide, operations guide, adapter schema, and relevant scripts;
5. inspect the complete test layout and runner conventions;
6. verify whether v1.0.1 hardening is already implemented;
7. record any interface differences from this plan.

Exit condition: implementation assumptions match the current repository.

## Phase 1 — Add Runtime Detection Tests

Write failing tests first for:

- Codex-only detection;
- Claude-only detection;
- Gemini-only detection;
- all three detected;
- none detected;
- instruction file missing while runtime directory exists;
- disabled adapter;
- unsupported installation;
- invalid target path;
- deterministic Codex, Claude, Gemini ordering;
- no directory creation.

Use temporary adapter data or test fixtures and temporary user-profile roots. Do not mutate actual adapters or user folders.

Exit condition: tests fail for the expected missing detection behavior.

## Phase 2 — Implement Runtime Detection

1. add `RuntimeDetection.ps1`;
2. reuse `Import-AdapterConfig`, `Resolve-AdapterInstallPath`, `Get-AdapterApprovedRoots`, and path validation helpers;
3. return a result for every supported runtime, not just detected ones;
4. ensure errors are explicit and safe;
5. run detection tests in PowerShell 5.1 and PowerShell 7 where available.

Exit condition: all runtime detection tests pass.

## Phase 3 — Add Refresh Workflow Tests

Write failing tests for:

- only detected runtime IDs are processed;
- deterministic ordering;
- build before verify before install before installed verification;
- first failure stops subsequent runtimes;
- completed earlier runtimes remain reported as successful;
- already-current installation is successful;
- `-Force` reaches installation;
- preview occurs before installation;
- no-runtime input produces a controlled result;
- restart list contains only changed runtimes.

Use injectable script paths, command invokers, or temporary wrapper scripts to avoid touching production runtime paths.

Exit condition: orchestration behavior is specified by failing tests.

## Phase 4 — Implement Shared Refresh Workflow

1. add `RefreshWorkflow.ps1`;
2. invoke existing child scripts with fixed arguments;
3. validate `$LASTEXITCODE` after every child script;
4. capture phase, runtime, action, and target in structured results;
5. retain sequential fail-fast behavior;
6. generate partial-success summary data;
7. avoid transactional rollback across runtimes.

Exit condition: orchestration tests pass and current low-level tests remain green.

## Phase 5 — Implement First-Time Setup Command

Write tests, then implement `setup-agent-system.ps1`.

Required flow:

1. load shared libraries;
2. resolve repository root;
3. validate manifest and adapters;
4. detect Codex, Claude, and Gemini;
5. print detection table;
6. exit `2` when none are detected;
7. invoke shared refresh workflow;
8. forward `-Force`, `-WhatIf`, and confirmation semantics;
9. display final summary;
10. display restart guidance.

Test:

- successful one-runtime setup;
- successful multi-runtime setup;
- no runtimes;
- build failure;
- install failure;
- partial sequential success;
- `-WhatIf` no writes;
- `-Force` forwarding.

Exit condition: setup command works entirely against temporary targets.

## Phase 6 — Implement Sync Git Safety Tests

Write failing tests for:

- Git unavailable;
- not a Git repository;
- clean `main` accepted;
- wrong branch rejected;
- detached HEAD rejected;
- tracked changes rejected;
- untracked changes rejected;
- pull failure prevents refresh;
- successful pull precedes detection and refresh;
- `-SkipPull` bypasses Git invocation;
- `-WhatIf` does not invoke pull;
- no automatic stash, reset, clean, checkout, or commit commands.

Use a temporary local Git repository and local bare remote where integration-level behavior is valuable. Use command injection/mocking only where supported by the repository's Pester-independent test model.

Exit condition: Git contract is executable and failing before implementation.

## Phase 7 — Implement Sync Command

Implement `sync-agent-system.ps1`:

1. resolve repository root;
2. when not `-SkipPull`, run Git safety checks;
3. under `-WhatIf`, print the pull that would run but do not run it;
4. run `git pull --rebase origin main`;
5. stop with exit `3` on precondition or pull failure;
6. reload configuration after pull;
7. detect runtimes;
8. exit `2` when none are detected;
9. invoke shared refresh;
10. display final summary and restart guidance.

Ensure the current process working directory does not need to be the repository root. External commands should execute with the repository root as their working directory or with an explicit `-C` argument where PowerShell 5.1 compatibility permits.

Exit condition: sync tests pass and a temporary remote integration test demonstrates pull-before-refresh behavior.

## Phase 8 — Documentation and Compatibility

Update:

### `README.md`

Replace the existing quick-start recommendation with:

```powershell
# First time after cloning
.\scripts\setup-agent-system.ps1

# Later updates
.\scripts\sync-agent-system.ps1
```

Keep links to advanced commands.

### `docs/INSTALLATION.md`

Document:

- prerequisites: Git, PowerShell, repository clone, initialized supported runtime;
- runtime detection directories;
- no-runtime behavior;
- setup output;
- backup and rollback behavior;
- restart requirements;
- `-WhatIf`, `-Confirm`, and `-Force`.

### `docs/OPERATIONS.md`

Document:

- default sync;
- `-SkipPull` developer path;
- dirty-tree refusal;
- wrong-branch refusal;
- pull conflict handling;
- targeted advanced commands;
- sequential partial-success behavior.

### `docs/PRD.md`

Record the streamlined setup/sync workflow as approved product behavior without converting deferred background updating or broader runtime support into requirements.

### Compatibility wrappers

Keep current wrappers. Optionally update `update-all-agents.ps1` help text to point users to `sync-agent-system.ps1`, but do not silently change it to pull from Git because that would alter established behavior.

Exit condition: documentation exactly matches implementation.

## Phase 9 — Verification

Run at minimum:

```powershell
.\scripts\build-agent.ps1 -Runtime All -Check
.\scripts\verify-agent.ps1 -Scope All -Strict
.\tests\run-tests.ps1
```

Also run targeted manual scenarios in isolated temporary profiles:

1. only `.codex` exists;
2. `.claude` and `.gemini` exist;
3. none exist;
4. clean local clone behind a local remote;
5. dirty working tree;
6. pull conflict simulation;
7. already-current files;
8. one child runtime failure after a prior success;
9. `-SkipPull` with local source edits;
10. `-WhatIf` with no writes and no pull.

Verify:

- generated files remain deterministic;
- real user runtime directories were not accessed by tests;
- installed target hashes match generated hashes in manual isolated tests;
- restart guidance is accurate;
- exit codes match the specification;
- PowerShell 5.1 and PowerShell 7 pass.

## 6. Detailed Task Breakdown

| ID | Task | Depends on | Verification |
| --- | --- | --- | --- |
| SS-01 | Revalidate current repository and v1.0.1 state | — | Documented findings |
| SS-02 | Add runtime detection tests | SS-01 | Expected failures |
| SS-03 | Implement adapter-driven runtime detection | SS-02 | Detection tests pass |
| SS-04 | Add refresh orchestration tests | SS-03 | Expected failures |
| SS-05 | Implement shared refresh workflow | SS-04 | Orchestration tests pass |
| SS-06 | Add setup command tests | SS-05 | Expected failures |
| SS-07 | Implement setup command | SS-06 | Setup tests pass |
| SS-08 | Add Git sync tests | SS-05 | Expected failures |
| SS-09 | Implement Git safety and pull | SS-08 | Git tests pass |
| SS-10 | Implement sync command | SS-07, SS-09 | Sync tests pass |
| SS-11 | Update user and product documentation | SS-10 | Docs review |
| SS-12 | Run complete verification matrix | SS-11 | All checks pass |
| SS-13 | Record verified outcome in Ideas Hub | SS-12 | Durable project record updated |

## 7. Key Implementation Decisions

### Adapter-driven paths

Runtime directories are derived from adapter installation paths. No second hard-coded path registry should be introduced.

### Fixed supported-runtime allowlist

Although adapters are extensible, the high-level MVP explicitly allows only:

```text
codex
claude
gemini
```

This prevents a newly added or experimental adapter from being automatically installed by the user-facing sync command without product approval.

### No implicit folder creation

Detection checks parent runtime directories before any build or installation. Missing directories are reported, not created.

### No automatic Git recovery

Dirty trees, wrong branches, conflicts, and failed pulls stop the workflow. The script explains the condition but does not modify developer work.

### Shared orchestration

Setup and sync differ only in whether a Git pull occurs first. Detection and refresh logic must be shared.

### Compatibility over cleanup

Existing scripts remain functional. Do not combine this feature with removal or broad refactoring of current wrappers.

## 8. Risks and Mitigations

### Risk: Adapter path validation occurs too late

**Mitigation:** Validate adapter paths before filesystem detection and reuse approved-root helpers.

### Risk: `git pull --rebase` disrupts local changes

**Mitigation:** Require a clean working tree and refuse to auto-stash or reset.

### Risk: `-WhatIf` accidentally performs a pull

**Mitigation:** Treat pull as a mutating operation and add a dedicated test proving no Git pull occurs.

### Risk: Child scripts expose only console output

**Mitigation:** Initially use exit codes and deterministic messages. Add the smallest structured-result interface only if restart/partial-success reporting cannot be implemented reliably otherwise.

### Risk: Setup and sync drift over time

**Mitigation:** Centralize detection and refresh orchestration in shared libraries and test both entry points against the same workflow.

### Risk: New workflow bypasses hardening protections

**Mitigation:** Call existing verified scripts instead of duplicating installation logic.

### Risk: Tests touch real user profiles

**Mitigation:** support test roots/target maps and assert that production runtime paths are never accessed.

### Risk: Direct-to-main implementation creates breaking commits

**Mitigation:** direct-to-main should be used only when separately and explicitly authorized for implementation. Make focused commits, run verification before each final status claim, and do not mark the task complete until all checks pass.

## 9. Definition of Done

Implementation is done only when:

- both new commands exist and have complete help text;
- all three runtimes are detected through adapter-derived directories;
- setup installs only detected runtimes;
- sync safely pulls by default and supports `-SkipPull`;
- no-runtime and Git failures use documented exit codes;
- workflows are sequential, deterministic, and fail-fast;
- partial success is clearly reported;
- existing backup, rollback, path validation, and hash verification remain active;
- all automated tests pass in supported PowerShell versions;
- manual isolated-profile tests pass;
- existing low-level commands remain operational;
- README, installation, operations, PRD, specification, and command help agree;
- the verified outcome is recorded in the Agent System Ideas Hub project record.

## 10. Recommended Commit Sequence

When implementation is approved:

1. `test: define runtime detection behavior`
2. `feat: detect supported agent runtimes`
3. `test: define setup and refresh orchestration`
4. `feat: add streamlined agent setup`
5. `test: define safe repository sync behavior`
6. `feat: add one-command agent synchronization`
7. `docs: document streamlined setup and sync`
8. `test: complete setup and sync verification`

Commits may be consolidated when changes are tightly coupled, but detection, Git safety, and documentation should remain reviewable.
