# Coding Guidelines

Use these only after the Shared Understanding has been approved or the user has explicitly bypassed Discovery.

## General Principles

- Follow the repository architecture.
- Reuse existing patterns, utilities, and naming conventions.
- Prefer modifying existing files over adding new structures.
- Keep changes minimal and narrowly scoped.
- Keep code production-ready.
- Minimize dependencies and check package manifests before importing libraries.
- Preserve backward compatibility unless requirements changed.
- Do not repeat these instructions to the user.

## Code Quality

Code must be:

- readable
- deterministic
- testable
- maintainable
- consistent with the codebase

Avoid:

- placeholder code
- fake implementations
- duplicated logic
- unnecessary abstractions
- unnecessary comments
- speculative features
- over-engineering

## Bug Fixes

- Find the root cause.
- Do not patch symptoms.
- Preserve existing behavior unless intentionally changed.
- Add or update regression tests when practical.

## Null And Optional Data

Never assume nested objects, arrays, or fields always exist. Handle:

- null
- undefined
- empty string
- empty array
- missing keys

Backend and frontend must both tolerate optional data intentionally.

## Idempotency And Duplicate Actions

Prevent duplicate writes caused by double submission, retries, repeated webhooks, or repeated job execution. Mutations that can be triggered more than once must handle duplicate execution safely. Do not rely on the frontend alone to prevent duplicate actions.

## Performance

Consider unnecessary renders, duplicate work, expensive computation, unnecessary network requests, and inefficient database queries. Optimize only when it improves maintainability or meets a real requirement.

## Version Control

Do not rewrite history, force push, or delete branches unless explicitly instructed.

## Default Technical Preferences

These apply only when the repository does not establish its own stack.

Frontend:

- React
- Vite
- TypeScript
- Tailwind CSS
- TanStack Query for server state
- Redux Toolkit only for true global client state

Backend:

- Node.js
- Express
- MongoDB

Testing:

- Vitest for frontend
- Jest for backend

Scraping:

- Crawlee

Package manager:

- npm

## Deliverables

For implementation tasks, provide a summary, a TDD or verification summary when applicable, the changed files, complete updated files only when helpful or requested, and notes only when necessary. Avoid partial implementations unless requested.

## Definition Of Done

A task is complete when:

- implementation matches the approved Shared Understanding
- repository conventions are followed
- code is production-ready
- relevant tests are updated
- tests pass or any inability to run them is explained
- frontend UI work follows the frontend taste rules
- no unnecessary complexity is introduced
