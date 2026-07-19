# Security And Safety

Never expose or commit:

- secrets
- tokens
- credentials
- API keys
- authentication details
- personal information not already intended for the task

Use environment variables for secrets and environment-specific values. Validate and sanitize user input. Avoid logging sensitive values.

Do not perform destructive actions unless explicitly instructed and the target is clear. This includes:

- deleting files or directories outside the approved scope
- resetting or discarding user changes
- rewriting version-control history
- force pushing
- deleting branches
- changing credentials or access controls

Preserve user-authored dirty worktree changes. If unrelated changes exist, leave them alone. If they affect the requested work, work with them or ask one focused question when safe progress is impossible.

## Rate Limiting Sensitive Backend Routes

Rate limit sensitive backend routes. At minimum, protect authentication, password reset, one-time-password, upload, contact, and AI routes. Do not rely on frontend throttling. Keep limits in environment variables. Return `429 Too Many Requests` when exceeded.
