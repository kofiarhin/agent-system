# Preferences

Durable, user-stated preferences that shape default behavior across projects. These are supporting context only. Current user instructions, repository-specific instruction files, and current repository state always take priority.

## Stack Defaults

Apply only when the repository does not establish its own stack.

- Frontend: React, Vite, TypeScript, Tailwind CSS; React Router for routing; Axios as the shared API client.
- Server state: TanStack Query.
- Global client state: Redux Toolkit, for true global client state only.
- Backend: Node.js, Express, MongoDB (Mongoose).
- Frontend tests: Vitest with React Testing Library.
- Backend tests: Jest with Supertest.
- Scraping: Crawlee.
- Package manager: npm.

## Standing Engineering Rules

- Rate limit sensitive backend routes; keep limits in environment variables; return `429 Too Many Requests` when exceeded.
- Tolerate optional data intentionally on both backend and frontend (null, undefined, empty string, empty array, missing keys).
- Make mutations that can run more than once idempotent; do not rely on the frontend alone to prevent duplicate actions.

## Communication

- Be concise; avoid filler.
- Do not expose internal reasoning.
- Avoid emojis unless requested.
