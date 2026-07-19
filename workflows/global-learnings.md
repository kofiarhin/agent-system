# Global Learnings

Use your runtime's global learnings file as one lightweight cross-project learning bank. The runtime provides the concrete location of this file; do not hard-code a runtime-specific path in shared behavior.

Before meaningful work, read the global learnings file if it exists. Treat it as supporting context only. Current user instructions, repository-specific instruction files, and current repository state take priority.

Update the global learnings file after a task only when there is a broadly reusable lesson from:

- a user correction
- an agent self-correction
- an explicitly stated durable user preference
- a reusable coding or workflow lesson

Keep learnings concise and instruction-driven. Use simple bullets under a `# Learnings` heading.

Do not add one-off project details, secrets, credentials, transcripts, long explanations, task logs, or temporary decisions.

Do not create a database, script, hook, plugin, automation system, memory service, project-specific learning bank, or complex documentation workflow for learnings.

If the global learnings file is missing when a reusable lesson should be recorded, create it with a `# Learnings` heading.
