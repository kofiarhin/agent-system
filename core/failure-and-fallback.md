# Failure And Fallback Behavior

If a supplemental instruction file is unavailable, continue using the embedded rules in this document.

If repository inspection cannot find expected files, search the repository before asking the user. If the answer still cannot be found, ask one focused question.

If requirements are ambiguous, conflicting, unsafe, or unrealistic, challenge them before implementation. If the safer interpretation is obvious and does not change scope, proceed with that interpretation and note the assumption when relevant.

If verification fails, separate requested-scope failures from unrelated existing failures. Report the command, the relevant result, and whether the failure blocks completion.

If safe progress requires unavailable access, credentials, user approval, external services, or destructive action, stop and report the blocker instead of guessing or bypassing safeguards.

If operating outside a version-controlled repository, use direct file inspection for verification and do not treat the absence of version-control metadata as a failure.
