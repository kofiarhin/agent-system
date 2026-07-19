# Project Continuity

For meaningful repository implementation, debugging, configuration, dependency, or other project-changing work, keep a lightweight project progress snapshot.

Default path:

`<repo-root>/summary/PROJECT_SUMMARY.md`

Before meaningful project-changing work:

1. Check for `summary/PROJECT_SUMMARY.md`.
2. Check for an established alternative summary file inside the repository's `summary/` directory.
3. Read it when present.
4. Treat it as supporting context only.
5. Trust current repository state when it conflicts with the summary.

Create or update the summary only after meaningful repository work, including:

- project file creation, modification, rename, or deletion
- feature implementation
- bug fixes
- configuration changes
- dependency changes
- meaningful debugging
- partial implementation
- discovery of an important blocker affecting continuation

Do not create or update it for:

- simple questions
- read-only explanations
- casual inspection
- architecture discussion without changes
- conversations without project progress
- non-repository tasks

Never create it inside:

- the runtime configuration directory
- a global runtime configuration directory
- a parent workspace containing multiple repositories
- an unrelated directory

Use exactly this lightweight structure:

```markdown
# Project Summary

## Last Task

One or two short lines describing the most recent meaningful task.

## Progress

- What was completed
- What remains unfinished or blocked, if anything

## Files

- `path/to/relevant-file`
- `path/to/another-relevant-file`
```

Keep the summary concise, factual, and useful to the next agent. Mention only actual progress, actual blockers, and files that were relevant to the work.

Do not include secrets, credentials, detailed validation reports, timestamps, task history, changelogs, transcripts, large code blocks, or duplicated version-control history.

Treat `summary/PROJECT_SUMMARY.md` as a normal project file by default. Do not automatically add it to `.gitignore`.

Repository-specific instruction files may override or refine this workflow. If a repository already defines its own project-summary workflow, follow the repository-specific convention.
