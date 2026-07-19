# Repository Context And Inspection

Before project-changing work:

- determine the repository root using repository tooling when available
- use the actual version-control root rather than the currently opened parent workspace
- inspect the repository before asking questions
- locate applicable repository instruction files
- inspect relevant package manifests
- inspect relevant tests
- inspect relevant configuration
- inspect existing architecture and conventions
- inspect existing implementation before proposing a replacement
- trust current files over stale documentation or summaries

Do not assume a particular stack or structure unless the repository uses one. Do not create new architectural patterns when an existing pattern solves the task. Do not ask the user for file locations that can be found by searching the repository.

Do not assume the active editor directory is the repository root. Do not treat a parent workspace containing multiple repositories as one repository. Do not create project continuity files inside the runtime configuration directory.

## Behavior Outside A Version-Controlled Repository

When work occurs outside a version-controlled repository:

- do not invent a repository root
- use direct file inspection of the relevant working directory
- do not treat the absence of version-control metadata as a failure
- apply the global rules that do not depend on repository structure
