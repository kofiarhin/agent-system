# Runtime Adapter Guide

Adapters make one set of shared instruction modules deployable to multiple AI coding
runtimes. A runtime is a delivery target (Codex, Claude Code, Gemini CLI, a custom
API prompt). The *behavior* is shared; the adapter only describes runtime *mechanics*.

---

## Adapter Schema

Each adapter is `adapters/<id>.json` and conforms to
`config/schemas/adapter.schema.json`.

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

### Field reference

| Field | Purpose |
|---|---|
| `id` | Lowercase runtime id; must match the filename and the `runtimes` list in `config/agent.json`. |
| `displayName` | Human-readable name shown in tooling output. |
| `enabled` | When false, `-Runtime All` skips this runtime. |
| `output.directory` | Repository-relative directory under `generated/`. Must not escape `generated/`. |
| `output.filename` | Generated file name (e.g. `AGENTS.md`, `CLAUDE.md`, `SYSTEM_PROMPT.md`). |
| `installation.supported` | Whether `install-agent.ps1` can deploy this runtime. |
| `installation.path` | Absolute install target; `%VAR%` environment variables are expanded. |
| `installation.approvedRoots` | Allowlist of roots the install/restore target must fall inside. |
| `document.title` | First heading of the generated document. |
| `document.runtimeHeader` | Lines describing how the runtime resolves its own instruction files. This is the **only** place runtime-specific resolution notes belong. |
| `compatibility.mode` | `full` — the entire shared behavior is compiled inline. |
| `compatibility.supportsImports` | Reserved; v1 uses full compilation for portability. |

---

## Allowed vs Prohibited Responsibilities

**Allowed in adapters (runtime mechanics only):**

- runtime id and display name
- generated output directory and filename
- install target path and approved roots
- document title
- runtime header / instruction-resolution notes
- compilation compatibility settings

**Prohibited in adapters (belongs in shared modules):**

- coding guidelines, stack preferences, testing rules
- discovery, approval, implementation, or continuity workflow
- security, output, failure, or invariant policy
- any behavior that should be identical across runtimes

Shared behavior lives in `core/`, `workflows/`, `capabilities/`, and `memory/`.
Adapters must never redefine it.

---

## How To Add a Runtime

1. Create `adapters/<id>.json` following the schema above. Choose a unique
   `output.directory` under `generated/`.
2. Add `"<id>"` to the `runtimes` array in `config/agent.json`.
3. (Optional) Add runtime-specific tests under `tests/`.
4. Build: `./scripts/build-agent.ps1 -Runtime <id>`.
5. Verify: `./scripts/verify-agent.ps1 -Scope Generated -Runtime <id>`.
6. Review the generated file under `generated/<id>/`.
7. Preview installation: `./scripts/install-agent.ps1 -Runtime <id> -WhatIf`.
8. Install explicitly: `./scripts/install-agent.ps1 -Runtime <id>`.

No shared module should need editing solely to add a runtime.

### Choosing install paths

- Use an absolute path with environment variables (`%USERPROFILE%\...`).
- Set `approvedRoots` to the narrowest directory that contains the target. The
  installer and restore tooling refuse to write outside these roots.
- For runtimes without a stable on-disk location (e.g. an API system prompt), set
  `installation.supported` to `false` and omit `path`. The `generic` adapter is the
  reference example.

---

## Validation Requirements

`verify-agent.ps1` and `build-agent.ps1` enforce:

- required fields present; `id` matches filename
- `compatibility.mode` is `full`
- output path is unique and inside `generated/`
- no duplicate runtime ids
- (for install/restore) target inside an approved root; no reparse points

---

## Example: minimal generic adapter

```json
{
  "$schema": "../config/schemas/adapter.schema.json",
  "id": "generic",
  "displayName": "Generic Runtime",
  "enabled": true,
  "output": { "directory": "generated/generic", "filename": "SYSTEM_PROMPT.md" },
  "installation": { "supported": false },
  "document": {
    "title": "SYSTEM_PROMPT.md",
    "runtimeHeader": [
      "This is a runtime-neutral system prompt for custom applications, API system prompts, and unsupported runtimes."
    ]
  },
  "compatibility": { "mode": "full", "supportsImports": false }
}
```
