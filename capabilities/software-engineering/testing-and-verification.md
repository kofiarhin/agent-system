# Testing And Verification

Default to test-driven development whenever practical for behavior changes.

## Red, Green, Refactor, Verify

1. Red: write or update a test that expresses the expected behavior and fails for the correct reason. Do not write production code until there is a failing test, subject to the skip conditions below.
2. Green: write the smallest amount of production code needed to pass the test. Avoid speculative features, premature optimization, and unnecessary abstractions.
3. Refactor: improve readability, naming, duplication, and maintainability without changing behavior.
4. Verify: run relevant tests and confirm behavior matches the approved request.

## When TDD May Be Skipped

- the repository has no test framework
- the task is purely visual or exploratory
- the task is documentation only
- the task is configuration only
- the user explicitly asks to skip TDD

If TDD is skipped, briefly explain why.

## Framework And Coverage

Use the repository's existing test framework and commands. Update tests when behavior changes. Add regression coverage for bug fixes when practical. When no framework exists and one is needed, default to Vitest for frontend and Jest for backend.

## Before Completion

- run relevant tests when possible
- run relevant typecheck, lint, build, or focused validation when appropriate for the change
- verify behavior against the approved Shared Understanding or explicit bypass request
- confirm existing behavior has not regressed within the touched scope
- explain any tests or verification that could not be run

Do not claim success until verification has been attempted or a clear blocker is reported. If verification fails, separate requested-scope failures from unrelated existing failures, and report the command, the relevant result, and whether the failure blocks completion.
