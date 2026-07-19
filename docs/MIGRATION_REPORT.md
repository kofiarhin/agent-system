# Migration Report

**System:** Universal Agent System
**Migration:** Global Codex instruction architecture → model-agnostic shared modules
**Date (UTC):** 2026-07-19
**Backup ID:** `20260719-031433Z`
**Execution mode:** Build and verify only. Production installation was **not** performed.

---

## 1. Source Inventory

The audit inspected the global runtime configuration directories under the user
home directory. Files were classified as user-maintained instruction content
(migrated) or runtime state (excluded). No source file was modified during the audit.

| Source path | Type | Instruction content | Migrated | Reason | Destination |
|---|---|---|---|---|---|
| `.codex/AGENTS.md` | Markdown | Yes | Yes | Primary behavioral baseline | core/*, workflows/*, capabilities/*, memory/* |
| `.codex/LEARNINGS.md` | Markdown | Yes | Yes | Global learnings bank (header only, empty) | memory/learnings.md |
| `.codex/instructions/discovery.md` | Markdown | Yes | Yes | Discovery protocol detail | workflows/discovery.md, workflows/approval-gate.md |
| `.codex/instructions/coding-guidelines.md` | Markdown | Yes | Yes | Coding + testing detail | capabilities/software-engineering/coding-guidelines.md, testing-and-verification.md |
| `.codex/instructions/frontend-taste.md` | Markdown | Yes | Yes | Frontend design skill | capabilities/software-engineering/frontend-taste.md |
| `.claude/CLAUDE.md` | Markdown | Yes | Yes | Stack + backend robustness rules | memory/preferences.md, capabilities/.../coding-guidelines.md, core/security-and-safety.md |
| `.gemini/GEMINI.md` | Markdown | Yes (empty) | Yes (no content) | 0 bytes; nothing to migrate. Covered by shared modules | n/a |

### Excluded runtime state (not instruction content)

The following were explicitly excluded via allowlist filtering. None were copied,
modified, or backed up.

- Databases / indexes: `.codex/*.sqlite`, `*.sqlite-shm`, `*.sqlite-wal`, `.codex/goals_1.sqlite`, `memories_1.sqlite`, `state_5.sqlite`, `logs_2.sqlite`
- History / sessions: `.codex/history.jsonl`, `session_index.jsonl`, `.codex/sessions/`, `.claude/history.jsonl`, `.claude/sessions/`, `.claude/projects/`, `.claude/shell-snapshots/`
- Authentication / credentials: `.codex/auth.json`, `.claude/.credentials.json`
- Configuration / runtime settings: `.codex/config.toml`, `.codex/version.json`, `.codex/installation_id`, `.claude/settings.json`
- Sandbox permission rules: `.codex/rules/default.rules` (execution allowlist, not instruction content)
- Logs / telemetry: `.codex/sandbox.*.log`, `.codex/log/`, `.claude/telemetry/`
- Caches: `.codex/cache/`, `.codex/models_cache.json`, `.claude/cache/`, `.claude/paste-cache/`
- Plugins / skills / binaries: `.codex/plugins/`, `.codex/skills/`, `.codex/.sandbox-bin/`, `.claude/plugins/`, `.claude/skills/`, `.claude/ide/`
- Miscellaneous state: `.codex/memories/`, `.codex/automations/`, `.codex/computer-use/`, `.codex/pets/`, `.codex/generated_images/`, `.codex/.codex-global-state.json`, `.codex/cap_sid`, `.codex/.personality_migration`

---

## 2. Backup

A verified, timestamped backup of all migrated source files was created before any
change, under `backups/20260719-031433Z/`.

- Format: `yyyyMMdd-HHmmssZ` (UTC)
- Files backed up: 7
- Every backup verified by SHA-256 against its source (all matched).
- Reparse points were refused (none encountered).
- No runtime caches, logs, sessions, databases, authentication files, or plugins were backed up.

| Source | Size | SHA-256 (prefix) |
|---|---|---|
| `.codex/AGENTS.md` | 19502 | `C799F5B5E124…` |
| `.codex/LEARNINGS.md` | 13 | `3ADAAA782255…` |
| `.codex/instructions/coding-guidelines.md` | 4976 | `738514A9DBA1…` |
| `.codex/instructions/discovery.md` | 2594 | `104E7468DC89…` |
| `.codex/instructions/frontend-taste.md` | 21424 | `044E71AEDD27…` |
| `.claude/CLAUDE.md` | 1144 | `739395193661…` |
| `.gemini/GEMINI.md` | 0 | `E3B0C44298FC…` |

The full manifest (original path, backup path, SHA-256, size, last-write time,
backup timestamp) is at `backups/20260719-031433Z/manifest.json`.

---

## 3. Rule Migration Mapping (Traceability)

Every rule from the source instructions maps to exactly one owning shared module, or
is documented as excluded. Change types: `unchanged`, `wording normalized`,
`path generalized`, `duplicate consolidated`, `runtime-specific rule moved to adapter`.

| Source file | Source section | Rule summary | Target module | Change type |
|---|---|---|---|---|
| `.codex/AGENTS.md` | 1. Purpose And Scope | Global entry point; applies across projects; sufficient without supplemental files | `core/purpose-and-scope.md` | wording normalized |
| `.codex/AGENTS.md` | 2. Instruction Precedence | 7-level precedence; specificity; conflict handling; summaries never override current state | `core/instruction-precedence.md` | path generalized |
| `.codex/AGENTS.md` | 2. Instruction Precedence | `~/.codex/AGENTS.md` as global entry | `core/instruction-precedence.md` | path generalized → "global runtime instruction entry point" |
| `.codex/AGENTS.md` | 3. Request Classification | Conversational/read-only behavior | `core/request-classification.md` | unchanged |
| `.codex/AGENTS.md` | 3. Request Classification | Project-changing behavior | `core/request-classification.md` | unchanged |
| `.codex/AGENTS.md` | 3. Request Classification | Explicit discovery bypass | `core/request-classification.md` | unchanged |
| `.codex/AGENTS.md` | 3. Request Classification | Non-repository task | `core/request-classification.md` | wording normalized ("version-controlled repository") |
| `.codex/AGENTS.md` | 4. Operating Lifecycle | 13-step lifecycle; Discovery/Implementation separation | `core/operating-lifecycle.md` | unchanged |
| `.codex/AGENTS.md` | 4. Operating Lifecycle | Supplemental refs `~/.codex/instructions/*` | `core/operating-lifecycle.md` | path generalized (content inlined; external refs made optional) |
| `.codex/AGENTS.md` | 5. Discovery Protocol | Inspect before questions; one question; recommended answer; completeness; prohibitions; question format | `workflows/discovery.md` | duplicate consolidated (with `instructions/discovery.md`) |
| `.codex/AGENTS.md` | 6. Shared Understanding Approval Gate | Exact handoff structure; approval phrases; post-approval behavior | `workflows/approval-gate.md` | unchanged |
| `.codex/AGENTS.md` | 7. Implementation Protocol | 19-point pre/during implementation; scope discipline; preserve dirty worktree | `workflows/implementation.md` | wording normalized |
| `.codex/AGENTS.md` | 7. Implementation Protocol | Default engineering behavior | `workflows/implementation.md` + `capabilities/.../coding-guidelines.md` | duplicate consolidated |
| `.codex/AGENTS.md` | 7. Implementation Protocol | Default technical preferences (stack) | `capabilities/.../coding-guidelines.md`, `memory/preferences.md` | duplicate consolidated |
| `.codex/AGENTS.md` | 7. Implementation Protocol | Frontend fallback rules; `~/.codex/instructions/frontend-taste.md` ref | `capabilities/.../frontend-taste.md` | path generalized |
| `.codex/AGENTS.md` | 8. Repository Context And Inspection | Git root resolution; inspect before questions; no MERN assumption; no continuity in `~/.codex` | `core/repository-context.md` | path generalized |
| `.codex/AGENTS.md` | 9. Project Continuity | Summary path/read/update rules; what not to store; never inside `~/.codex` | `workflows/project-continuity.md` | path generalized |
| `.codex/AGENTS.md` | 10. Testing And Verification | TDD default; skip conditions; framework reuse; pre-completion verification | `capabilities/.../testing-and-verification.md` | duplicate consolidated |
| `.codex/AGENTS.md` | 11. Security And Safety | Secrets; destructive-op restrictions; force-push/history; preserve dirty worktree | `core/security-and-safety.md` | unchanged |
| `.codex/AGENTS.md` | 12. Output Requirements | Discovery output; implementation summary; changed files; concise; failure reporting | `core/output-requirements.md` | unchanged |
| `.codex/AGENTS.md` | 13. Global Learnings | Read/update learnings bank; prohibited content; lightweight format; `~/.codex/LEARNINGS.md` | `workflows/global-learnings.md` | path generalized ("your runtime's global learnings file") |
| `.codex/AGENTS.md` | 14. Failure And Fallback | Missing files; unresolved state; ambiguity; verification failure; missing access; non-Git | `core/failure-and-fallback.md` | wording normalized |
| `.codex/AGENTS.md` | 15. Global Invariants | Non-negotiable behavioral summary | `core/global-invariants.md` | wording normalized ("version-control"; "project-brain") |
| `.codex/instructions/discovery.md` | Core Rules / Before Asking / Format / Flow / Do Not / Completion / Final Output | Senior-architect discovery; one-at-a-time; recommended answer; handoff | `workflows/discovery.md`, `workflows/approval-gate.md` | duplicate consolidated |
| `.codex/instructions/coding-guidelines.md` | General / Red-Green-Refactor / Quality / Bug Fixes / Testing / Security / Performance / Git / Communication / Preferences / Deliverables / DoD | Engineering practice detail | `capabilities/.../coding-guidelines.md`, `.../testing-and-verification.md` | duplicate consolidated |
| `.codex/instructions/frontend-taste.md` | Sections 1–10 (design skill) | Frontend taste, architecture, bias correction, anti-slop, performance, dials, arsenal, bento, pre-flight | `capabilities/.../frontend-taste.md` | wording normalized; runtime frontmatter removed |
| `.claude/CLAUDE.md` | Tech Stack | React/Vite/Tailwind/Router/RTK/TanStack/Axios/Vitest/RTL; Node/Express/Mongo/Jest/Supertest | `memory/preferences.md`, `capabilities/.../coding-guidelines.md` | duplicate consolidated |
| `.claude/CLAUDE.md` | Rate Limit Rule | Rate limit sensitive routes; env-var limits; 429 | `core/security-and-safety.md`, `memory/preferences.md` | unchanged |
| `.claude/CLAUDE.md` | Null + Optional Data Rule | Tolerate optional data on both ends | `capabilities/.../coding-guidelines.md`, `memory/preferences.md` | unchanged |
| `.claude/CLAUDE.md` | Idempotency + Duplicate Action Rule | Safe duplicate execution; not frontend-only | `capabilities/.../coding-guidelines.md`, `memory/preferences.md` | unchanged |
| `.codex/AGENTS.md` (various) | Codex-specific global/repo AGENTS.md resolution notes | How the runtime resolves its own instruction files | `adapters/codex.json` (runtimeHeader) | runtime-specific rule moved to adapter |
| `.codex/LEARNINGS.md` | `# Learnings` | Empty learnings bank header | `memory/learnings.md` | unchanged (seed header) |

### Intentional wording changes

All wording changes preserve meaning. The categories are:

1. **Path generalization** — runtime-specific paths (`~/.codex/AGENTS.md`,
   `~/.codex/instructions/`, `~/.codex/LEARNINGS.md`, "global Codex configuration
   directory") were replaced with neutral concepts ("global runtime instruction
   entry point", "runtime configuration directory", "your runtime's global learnings
   file"). Runtime-specific resolution notes moved to adapter `runtimeHeader` fields.
2. **Terminology neutralization** — "Codex", "AGENTS.md", "Git" (as the only VCS)
   were generalized to "AI coding agents", "repository instruction file",
   "version control", except where a cross-runtime concept is being explained.
3. **Duplicate consolidation** — rules duplicated between `AGENTS.md` and the
   `instructions/*` files (discovery, TDD, stack preferences) were merged into a
   single owning module without changing precedence or meaning.

No behavioral rule was weakened, simplified away, or removed.

---

## 4. Behavioral Preservation Check

The following behaviors from the baseline are present in the shared modules and in
every compiled runtime artifact (verified as behavioral anchors by
`verify-agent.ps1`):

- [x] Request classification (conversational / project-changing / bypass / non-repo)
- [x] Explicit discovery bypass
- [x] One-question-at-a-time discovery
- [x] Recommended-answer question format
- [x] Shared Understanding Handoff (exact structure)
- [x] Approval gate (valid phrases; no implementation before approval)
- [x] Implementation protocol (scope discipline; preserve dirty worktree)
- [x] Repository inspection before questions
- [x] Project continuity (lightweight summary; never in runtime config dir)
- [x] TDD and verification rules
- [x] Coding preferences, stack preferences, Crawlee scraping preference
- [x] Frontend taste rules
- [x] Security safeguards (secrets; destructive ops; force-push/history)
- [x] Rate limiting, null/optional tolerance, idempotency rules
- [x] Output requirements (concise; changed files; failure reporting)
- [x] Global learnings (read/update; lightweight; prohibited content)
- [x] Failure and fallback behavior
- [x] Global invariants

---

## 5. Behavioral Equivalence Review — Codex

Comparison between the original global Codex instructions
(`backups/20260719-031433Z/.codex/AGENTS.md`, plus the referenced
`instructions/*.md`) and the generated `generated/codex/AGENTS.md`.

Byte-for-byte equality is **not** expected: the content was modularized, deduplicated,
and path-generalized. This is a traceability review.

- **All major source sections represented.** Each of the 15 numbered `AGENTS.md`
  sections maps to an owning module (see §3). The `instructions/*` detail files are
  folded into the corresponding capability/workflow modules.
- **All behavioral rules mapped.** Every rule has a destination in §3; anchors confirm
  presence in the compiled output.
- **Runtime coupling removed.** Shared modules contain no `.codex` / `.claude` /
  `.gemini` / `.cursor` path literals (enforced by source validation). Codex-specific
  instruction-resolution wording lives only in `adapters/codex.json`.
- **No meaningful instruction dropped.** Removed text is limited to: duplicated rules
  (consolidated), runtime-specific paths (generalized), and skill-file frontmatter.
- **Generated additions are limited** to: the generated-file warning, the document
  title, the runtime header (from the adapter), and `<!-- source: … -->` markers.
  None change behavior.

Difference between runtimes is limited to title, runtime header, and generated warning
placement. Full-compilation adapters (codex/claude/gemini/generic) share identical
shared-module content; the ~6-byte size differences across artifacts come only from
the differing title/header text.

---

## 6. Unresolved Concerns / Known Limitations

- `.gemini/GEMINI.md` was empty (0 bytes); there was no Gemini-specific content to
  preserve. The generated Gemini file is the full shared behavior with a Gemini header.
- The generated files are committed but **not installed**. Installation into the real
  runtime directories is a separate, manual, reviewed step.
- Schema files (`config/schemas/*.json`) document the contract; PowerShell performs the
  authoritative validation (no JSON Schema package is installed, per the no-install rule).
- Pester 3.4.0 is present but not used; the test suite is a self-contained,
  Pester-independent runner (`tests/run-tests.ps1`) per the plan's fallback allowance.

---

## 7. Final Migration Result

- Source inventoried; runtime state excluded via allowlist.
- Verified backup created (`20260719-031433Z`, 7 files, all SHA-256 matched).
- Shared modules created; every source rule mapped; no runtime paths in shared modules.
- Four runtime artifacts generated deterministically and verified (34 checks pass).
- Full test suite passes (33/33).
- **Production installation was not executed.**
