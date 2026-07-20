# Runtime Adapter Guide

Adapters make shared instruction modules deployable to multiple AI coding runtimes. Shared behavior lives in source modules; adapters describe runtime delivery mechanics only.

Adapters are also the source of truth for automatic runtime detection used by `setup-agent-system.ps1` and `sync-agent-system.ps1`.

## Adapter Schema

Each adapter is stored at `adapters/<id>.json` and conforms to `config/schemas/adapter.schema.json`.

```json
{
  "$schema": "../config/schemas/adapter.schema.json",
  "id": "codex",
  "displayName": "Codex",
  "enabled": true,
  "output": {
    "directory": "generated/codex",
    "filename": "AGENTS.md"
  },
  "installation": {
    "supported": true,
    "path": "%USERPROFILE%\\.codex\\AGENTS.md",
    "approvedRoots": ["%USERPROFILE%\\.codex"]
  },
  "document": {
    "title": "AGENTS.md",
    "runtimeHeader": [
      "This is the global Codex instruction entry point.",
      "Apply applicable repository-level AGENTS.md files.",
      "More specific repository instructions override broader instructions."
    ]
  },
  "compatibility": {
    "mode": "full",
    "supportsImports": false
  }
}
```

## Field Reference

| Field | Purpose |
|---|---|
| `id` | Lowercase runtime id matching the adapter filename and manifest entry. |
| `displayName` | Human-readable name used in detection and refresh output. |
| `enabled` | Whether the runtime participates in enabled-runtime operations. |
| `output.directory` | Repository-relative output directory under `generated/`. |
| `output.filename` | Runtime-native generated filename. |
| `installation.supported` | Whether installation tooling can deploy the runtime. |
| `installation.path` | Installed target with `%VAR%` environment expansion. |
| `installation.approvedRoots` | Narrow allowlist containing install and restore targets. |
| `document.title` | First heading of the generated document. |
| `document.runtimeHeader` | Runtime-specific instruction-resolution notes. |
| `compatibility.mode` | `full` means shared behavior is compiled inline. |
| `compatibility.supportsImports` | Reserved; current adapters use full compilation. |

## Automatic Detection Contract

The streamlined setup and sync workflows automatically support Codex, Claude Code, and Gemini CLI.

A runtime is detected when:

1. its adapter is in the supported setup/sync allowlist;
2. the adapter is enabled;
3. installation is supported;
4. `installation.path` resolves successfully;
5. the resolved target is within an approved root;
6. the target file's parent directory already exists.

The installed instruction file itself may be absent. This allows first-time Agent System installation into an already initialized runtime directory.

Detection is read-only. It must not create runtime directories or instruction files.

The detection directory is derived from the parent of `installation.path`; setup and sync must not maintain a second hard-coded path map.

| Adapter | Detection directory | Installed file |
|---|---|---|
| `codex` | `%USERPROFILE%\.codex` | `AGENTS.md` |
| `claude` | `%USERPROFILE%\.claude` | `CLAUDE.md` |
| `gemini` | `%USERPROFILE%\.gemini` | `GEMINI.md` |

The `generic` adapter is generated-only and excluded from automatic setup/sync because it has no supported production install target.

## Adapter Responsibilities

Allowed:

- runtime id and display name;
- generated output directory and filename;
- install target and approved roots;
- document title and runtime header;
- compilation compatibility settings.

Prohibited:

- coding, testing, discovery, approval, implementation, security, or reporting policy;
- behavior that should remain identical across runtimes;
- executable package-install or runtime-launch commands;
- duplicated setup/sync orchestration logic.

Shared behavior belongs in `core/`, `workflows/`, `capabilities/`, and `memory/`.

## Adding a Runtime

1. Create `adapters/<id>.json`.
2. Add the id to `config/agent.json`.
3. Build and verify:

   ```powershell
   .\scripts\build-agent.ps1 -Runtime <id>
   .\scripts\verify-agent.ps1 -Scope Generated -Runtime <id> -Strict
   ```

4. Review `generated/<id>/`.
5. When installation is supported, preview and install with the low-level installer.
6. Add isolated generation, validation, installation, and detection tests as applicable.

Adding an adapter does not automatically add it to the product-supported setup/sync allowlist. Expanding that allowlist requires separate discovery, approval, documentation, and tests.

## Choosing Installation Paths

- Use an absolute path with environment variables such as `%USERPROFILE%`.
- Set `approvedRoots` to the narrowest directory containing the target.
- Use the runtime's documented global instruction filename.
- For generated-only adapters, set `installation.supported` to false and omit the path.

## Validation Requirements

The tooling enforces required fields, id consistency, output containment under `generated/`, approved-root containment, reparse-point rejection, generated freshness, installed hash verification, read-only detection, and temporary-target isolation in tests.

## Generic Adapter Example

```json
{
  "$schema": "../config/schemas/adapter.schema.json",
  "id": "generic",
  "displayName": "Generic Runtime",
  "enabled": true,
  "output": {
    "directory": "generated/generic",
    "filename": "SYSTEM_PROMPT.md"
  },
  "installation": {
    "supported": false
  },
  "document": {
    "title": "SYSTEM_PROMPT.md",
    "runtimeHeader": [
      "This is a runtime-neutral system prompt for custom applications, API system prompts, and unsupported runtimes."
    ]
  },
  "compatibility": {
    "mode": "full",
    "supportsImports": false
  }
}
```
