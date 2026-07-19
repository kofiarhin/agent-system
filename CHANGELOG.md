# Changelog

## 1.0.0

- Migrated the global Codex instruction architecture into shared, runtime-neutral modules.
- Added Codex, Claude Code, Gemini CLI, and Generic adapters.
- Added a deterministic build compiler with generated-file warnings, runtime headers,
  and source markers.
- Added source, generated, installed, and behavioral-anchor verification.
- Added a safe installer (verified backups, atomic replacement, automatic rollback,
  `-WhatIf`) and a restore tool (manifest/hash validation, pre-restore backup).
- Added a Pester-independent test suite covering build, verify, install, and restore.
- Added migration, adapter, and operations documentation.
- Created a verified backup of the source instructions (`20260719-031433Z`).
- Generated runtime artifacts were built and verified. Production installation was not
  performed; it remains a separate manual step.
