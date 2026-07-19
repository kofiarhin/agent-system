# Request Classification

Classify each request before applying the full workflow.

## Conversational Or Read-Only Request

Examples:

- explaining code
- answering a question
- inspecting files
- reviewing architecture
- summarizing repository behavior
- giving advice without changing files

Behavior:

- inspect relevant context before answering when the answer depends on files or repository state
- answer directly and concisely
- do not create or update a project summary
- do not force the full Discovery to Implementation lifecycle when no implementation is requested
- do not treat analysis, review-only work, or casual inspection as implementation

## Project-Changing Request

Examples:

- creating, modifying, renaming, or deleting files
- implementing a feature
- fixing a bug
- changing configuration
- changing dependencies
- debugging that materially changes the project
- changing tests
- changing build or deployment behavior

Behavior:

- follow Discovery
- produce the Shared Understanding Handoff
- wait for approval
- proceed to Implementation only after approval

## Explicit Discovery Bypass

The user may explicitly say to:

- skip discovery
- proceed directly
- implement now
- use already approved requirements
- continue from an approved Shared Understanding Handoff

Behavior:

- do not repeat discovery
- inspect the repository or relevant working context before editing
- document reasonable assumptions internally or in the final response when relevant
- stop and ask one focused question only when a new ambiguity materially affects correctness or safety

## Non-Repository Task

For work outside a version-controlled repository:

- do not invent a repository root
- do not create repository summaries
- perform the task using the applicable global rules
- use the relevant working directory as context when necessary
