# Universal Agent System — Installation Guide

This guide takes a new Windows user from cloning the repository to a verified Codex or Claude Code installation.

For ongoing maintenance commands after installation, see [OPERATIONS.md](OPERATIONS.md).

## 1. Before You Start

The Universal Agent System uses shared Markdown modules to generate runtime-native instruction files. Installing the system does not point Codex or Claude Code directly at the repository. Instead, the workflow is:

```text
shared source → build → verify → review → install → verify → restart runtime
```

The active runtime files are copies of generated artifacts:

```text
Codex:      %USERPROFILE%\.codex\AGENTS.md
Claude Code:%USERPROFILE%\.claude\CLAUDE.md
Gemini CLI: %USERPROFILE%\.gemini\GEMINI.md
```

Do not edit those installed files manually. Edit the shared source in the repository, rebuild, and reinstall.

## 2. Supported Environment

Version 1 is designed primarily for:

- Windows 10 or Windows 11;
- Windows PowerShell 5.1 or PowerShell 7;
- Git;
- at least one supported runtime installed separately:
  - Codex;
  - Claude Code;
  - Gemini CLI.

PowerShell 7 is recommended, but the scripts are intended to remain compatible with Windows PowerShell 5.1.

## 3. Verify Prerequisites

Open **PowerShell**, not Command Prompt or Git Bash.

Check PowerShell:

```powershell
$PSVersionTable.PSVersion
```

Check Git:

```powershell
git --version
```

Confirm your user profile directory:

```powershell
$env:USERPROFILE
```

The examples in this guide install the repository at:

```text
%USERPROFILE%\agent-system
```

## 4. Clone the Repository

### HTTPS

```powershell
cd $env:USERPROFILE
git clone https://github.com/kofiarhin/agent-system.git
cd .\agent-system
```

### SSH

Use this option when your GitHub SSH key is already configured:

```powershell
cd $env:USERPROFILE
git clone git@github.com:kofiarhin/agent-system.git
cd .\agent-system
```

Confirm that you are in the repository root:

```powershell
Get-Location
Get-ChildItem
```

You should see directories including:

```text
core
workflows
capabilities
memory
adapters
config
generated
scripts
tests
docs
```

## 5. Understand What Is Already Generated

The repository commits generated runtime artifacts so they can be reviewed and checked for freshness.

Expected files include:

```text
generated\codex\AGENTS.md
generated\claude\CLAUDE.md
generated\gemini\GEMINI.md
generated\generic\SYSTEM_PROMPT.md
```

Inspect the first few lines of a generated file before installation:

```powershell
Get-Content .\generated\codex\AGENTS.md -TotalCount 12
Get-Content .\generated\claude\CLAUDE.md -TotalCount 12
```

Each file should contain a generated-file warning, a runtime-specific title or header, and source markers later in the document.

## 6. Run Initial Verification

Before building or installing, verify the repository state:

```powershell
.\scripts\verify-agent.ps1
```

A successful run validates the shared source, adapters, module ordering, generated artifacts, deterministic rebuild behavior, and behavioral anchors.

Stop if verification fails. Do not install an artifact that has not passed verification.

For stricter or runtime-specific checks:

```powershell
.\scripts\verify-agent.ps1 -Scope Source
.\scripts\verify-agent.ps1 -Scope Generated
.\scripts\verify-agent.ps1 -Scope Generated -Runtime codex -Strict
```

## 7. Build the Runtime Artifacts

Build every enabled runtime:

```powershell
.\scripts\build-agent.ps1 -Runtime All
```

Or build only the runtime you plan to install:

```powershell
.\scripts\build-agent.ps1 -Runtime codex
.\scripts\build-agent.ps1 -Runtime claude
```

The build writes only under `generated\`. It does not change active runtime files.

Run verification again after building:

```powershell
.\scripts\verify-agent.ps1
```

## 8. Review Generated Changes

Review generated output before installation:

```powershell
git status --short
git diff -- generated
```

For a fresh clone with no source changes, a clean build should normally produce no unexpected diff.

You can also inspect a complete artifact:

```powershell
Get-Content .\generated\codex\AGENTS.md
```

Only continue when the generated content matches the behavior you intend to deploy.

## 9. Installation Safety Recommendation

Install one runtime at a time and verify it before moving to the next runtime.

Although `-Runtime All` exists, the current deployment layer does not yet provide a fully durable all-or-nothing transaction across every runtime. Individual installation limits the effect of a partial failure and makes verification clearer.

Recommended order:

1. preview one runtime;
2. install that runtime;
3. verify the installed target;
4. restart and test the runtime;
5. repeat for the next runtime.

## 10. Install Codex

### Preview the installation

```powershell
.\scripts\install-agent.ps1 -Runtime codex -WhatIf
```

The preview should report:

- the generated source artifact;
- the target path;
- whether an existing target will be backed up;
- whether any directory or file would be created.

`-WhatIf` must not change files.

### Install

```powershell
.\scripts\install-agent.ps1 -Runtime codex
```

If a Codex `AGENTS.md` already exists, the installer creates a timestamped, hash-verified backup before replacing it.

### Verify the installed file

```powershell
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
```

You can also inspect the installed header:

```powershell
Get-Content "$env:USERPROFILE\.codex\AGENTS.md" -TotalCount 12
```

The installed file should match:

```text
generated\codex\AGENTS.md
```

## 11. Install Claude Code

### Preview the installation

```powershell
.\scripts\install-agent.ps1 -Runtime claude -WhatIf
```

### Install

```powershell
.\scripts\install-agent.ps1 -Runtime claude
```

### Verify the installed file

```powershell
.\scripts\verify-agent.ps1 -Scope Installed -Runtime claude
```

Inspect the installed header when needed:

```powershell
Get-Content "$env:USERPROFILE\.claude\CLAUDE.md" -TotalCount 12
```

The installed file should match:

```text
generated\claude\CLAUDE.md
```

## 12. Install Gemini CLI (Optional)

Gemini output is generated and verified by the repository, but production installation has not yet been confirmed as part of the current project milestone. Treat this installation as optional and review the adapter and generated file first.

### Inspect the generated artifact

```powershell
Get-Content .\generated\gemini\GEMINI.md -TotalCount 12
```

### Preview

```powershell
.\scripts\install-agent.ps1 -Runtime gemini -WhatIf
```

### Install

```powershell
.\scripts\install-agent.ps1 -Runtime gemini
```

### Verify

```powershell
.\scripts\verify-agent.ps1 -Scope Installed -Runtime gemini
```

After installation, confirm Gemini CLI recognizes `%USERPROFILE%\.gemini\GEMINI.md` according to the runtime version you use.

## 13. Verify All Installed Runtimes

After installing one or more runtimes:

```powershell
.\scripts\verify-agent.ps1 -Scope Installed
```

For explicit per-runtime confirmation:

```powershell
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
.\scripts\verify-agent.ps1 -Scope Installed -Runtime claude
```

A passing installed-scope verification confirms that active runtime files match their generated artifacts.

## 14. Restart Runtime Sessions

Runtime instruction files are generally loaded when a runtime or session starts.

After installation:

1. close active Codex, Claude Code, or Gemini sessions;
2. start a new session;
3. run a small, low-risk test request;
4. confirm the expected discovery, approval, implementation, and reporting behavior is active.

Do not assume an already-running session has reloaded the updated global instructions.

## 15. Confirm the Installed Architecture

A normal installation should look similar to:

```text
%USERPROFILE%
├── agent-system
│   ├── core
│   ├── workflows
│   ├── capabilities
│   ├── memory
│   ├── adapters
│   ├── generated
│   ├── scripts
│   └── docs
├── .codex
│   └── AGENTS.md
└── .claude
    └── CLAUDE.md
```

The repository remains the source of truth. The files under `.codex`, `.claude`, and `.gemini` are installed copies.

## 16. Standard Update Workflow

When changing agent behavior, edit only the shared source and configuration:

```text
core\
workflows\
capabilities\
memory\
config\
adapters\
```

Do not edit:

```text
generated\
%USERPROFILE%\.codex\AGENTS.md
%USERPROFILE%\.claude\CLAUDE.md
%USERPROFILE%\.gemini\GEMINI.md
```

Use this workflow:

```powershell
cd "$env:USERPROFILE\agent-system"

# 1. Edit shared source.

# 2. Build.
.\scripts\build-agent.ps1 -Runtime All

# 3. Verify source and generated output.
.\scripts\verify-agent.ps1

# 4. Run tests.
.\tests\run-tests.ps1

# 5. Review generated changes.
git diff -- generated

# 6. Preview and install one runtime at a time.
.\scripts\install-agent.ps1 -Runtime codex -WhatIf
.\scripts\install-agent.ps1 -Runtime codex
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex

.\scripts\install-agent.ps1 -Runtime claude -WhatIf
.\scripts\install-agent.ps1 -Runtime claude
.\scripts\verify-agent.ps1 -Scope Installed -Runtime claude

# 7. Commit source and generated changes together.
git add .
git commit -m "chore: update shared agent instructions"
```

## 17. Backups

When an existing runtime target is replaced, the installer stores a timestamped backup under the repository's backup area and records hashes in a manifest.

List available backups:

```powershell
.\scripts\restore-backup.ps1 -List
```

Review backup identifiers and included runtimes before restoring.

The backup directory contents are intentionally ignored by Git because they can contain local user configuration.

## 18. Restore a Previous Runtime File

Always preview a restore first.

### Restore the latest Codex backup

```powershell
.\scripts\restore-backup.ps1 -Latest -Runtime codex -WhatIf
.\scripts\restore-backup.ps1 -Latest -Runtime codex
```

### Restore the latest Claude Code backup

```powershell
.\scripts\restore-backup.ps1 -Latest -Runtime claude -WhatIf
.\scripts\restore-backup.ps1 -Latest -Runtime claude
```

### Restore a specific backup

```powershell
.\scripts\restore-backup.ps1 -BackupId 20260719-031433Z -Runtime codex -WhatIf
.\scripts\restore-backup.ps1 -BackupId 20260719-031433Z -Runtime codex
```

After restoration:

```powershell
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
```

A restored file may intentionally differ from the current generated artifact. In that case, inspect the restored target directly and decide whether to keep it, rebuild and reinstall the current source, or recover a different backup.

## 19. Uninstall or Return to the Previous File

There is no separate uninstall command in version 1. To remove the Universal Agent System from a runtime, restore the backup that was created before the first installation.

Recommended process:

```powershell
.\scripts\restore-backup.ps1 -List
.\scripts\restore-backup.ps1 -BackupId <backup-id> -Runtime codex -WhatIf
.\scripts\restore-backup.ps1 -BackupId <backup-id> -Runtime codex
```

If no previous runtime file existed, manually removing the installed target may be appropriate, but confirm the runtime's expected behavior first and preserve a copy before deletion.

## 20. Troubleshooting

### PowerShell blocks script execution

Check the current policy:

```powershell
Get-ExecutionPolicy -List
```

For a one-time process-scoped allowance:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

Then rerun the script in the same PowerShell session. Avoid changing machine-wide policy unless you understand the security implications.

### Verification reports stale generated files

Rebuild and verify:

```powershell
.\scripts\build-agent.ps1 -Runtime All
.\scripts\verify-agent.ps1
```

Then inspect:

```powershell
git diff -- generated
```

### Installed verification fails

The active runtime file does not match the current generated artifact, or the target is missing.

Inspect both files:

```powershell
Get-FileHash .\generated\codex\AGENTS.md -Algorithm SHA256
Get-FileHash "$env:USERPROFILE\.codex\AGENTS.md" -Algorithm SHA256
```

Preview and reinstall the affected runtime:

```powershell
.\scripts\install-agent.ps1 -Runtime codex -WhatIf
.\scripts\install-agent.ps1 -Runtime codex
.\scripts\verify-agent.ps1 -Scope Installed -Runtime codex
```

### The runtime still behaves as before

Close all active runtime sessions and start a new one. Confirm that the installed file exists at the runtime's expected global path.

### The installer rejects the target path

The installer restricts writes to approved adapter paths. Inspect the runtime adapter under `adapters\` and confirm the configured target is correct. Do not weaken path validation merely to bypass the error.

### A generated file was edited manually

Discard the manual edit and change the appropriate shared module instead:

```powershell
git checkout -- generated
# Edit shared source, then rebuild.
.\scripts\build-agent.ps1 -Runtime All
```

### Installation fails after creating a backup

Read the full error output, list backups, and verify the target before retrying:

```powershell
.\scripts\restore-backup.ps1 -List
.\scripts\verify-agent.ps1 -Scope Installed
```

Because multi-runtime installation is not yet a fully durable transaction, inspect each target separately after any failure involving `-Runtime All`.

## 21. Frequently Asked Questions

### Does cloning the repository activate the system?

No. Cloning and building create repository artifacts only. A runtime uses the system only after its generated file is explicitly installed into the runtime's configuration directory.

### Can I edit `.codex\AGENTS.md` or `.claude\CLAUDE.md` directly?

No. Those are installed copies and will drift from the shared source. Edit the repository modules, rebuild, verify, and reinstall.

### Why are generated files committed?

Committed artifacts make changes reviewable and allow freshness checks to detect when generated output no longer matches the source.

### Should I run `-Runtime All`?

For builds and verification, yes. For production installation, install one runtime at a time until multi-runtime transaction hardening is complete.

### Does installing global instructions replace repository-specific instructions?

No. Runtime-specific precedence rules still apply. Repository-local instructions may refine or override global behavior within their scope.

### Can I move the repository?

The scripts are intended to run from the repository root, but examples and common workflows assume `%USERPROFILE%\agent-system`. Review configuration and scripts before adopting a different layout.

### How do I add another runtime?

Follow [RUNTIME_ADAPTER_GUIDE.md](RUNTIME_ADAPTER_GUIDE.md), then build, verify, test, review, and install the new target explicitly.

## 22. Next Steps

After installation:

- read the [Product Requirements Document](PRD.md) for the product vision and requirements;
- use [OPERATIONS.md](OPERATIONS.md) for daily maintenance commands;
- use [RUNTIME_ADAPTER_GUIDE.md](RUNTIME_ADAPTER_GUIDE.md) when adding a runtime;
- review [MIGRATION_REPORT.md](MIGRATION_REPORT.md) for the original Codex migration and behavioral-equivalence record.
