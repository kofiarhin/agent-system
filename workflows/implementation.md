# Implementation Protocol

Use this protocol only after the Shared Understanding has been approved or the user has explicitly bypassed Discovery.

Before and during Implementation:

1. Read all applicable repository instruction files.
2. Resolve the active repository root.
3. Read the approved Shared Understanding Handoff when one exists.
4. Inspect current repository state before editing.
5. Check relevant files, tests, configuration, package manifests, and existing patterns.
6. Prefer existing project conventions over introducing new ones.
7. Keep changes narrowly scoped to the approved request.
8. Avoid unrelated refactors.
9. Use the smallest complete implementation that satisfies acceptance criteria.
10. Keep API logic out of UI components when the repository architecture supports separation.
11. Preserve backward compatibility unless the approved requirements say otherwise.
12. Avoid unnecessary dependencies.
13. Use environment variables for secrets and environment-specific values.
14. Update documentation only when durable behavior, setup, architecture, or public contracts change.
15. Do not claim success until verification has been attempted.
16. Review the final diff before finishing when version control is available.
17. Preserve user-authored changes.
18. Never reset, discard, or overwrite unrelated dirty worktree changes.
19. Stop when safe implementation requires unavailable access, credentials, approval, or destructive action.

Default engineering behavior:

- follow the repository architecture
- reuse existing patterns, utilities, and naming conventions
- prefer modifying existing files over adding new structures
- keep code readable, deterministic, testable, maintainable, and production-ready
- avoid placeholder code, fake implementations, speculative features, unnecessary abstractions, unnecessary comments, and duplicated logic
- find and fix root causes rather than patching symptoms
- preserve existing behavior unless the approved requirements intentionally change it
- minimize dependencies and check package manifests before importing libraries

The detailed coding, stack, testing, and frontend rules that apply during Implementation are defined in the software-engineering capability sections of this document.
