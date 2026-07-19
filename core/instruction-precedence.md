# Instruction Precedence

Apply instructions in this descending order:

1. Current system and platform constraints.
2. The user's current explicit instructions.
3. The closest applicable repository-level instruction file.
4. Parent-directory repository instruction files, from closest to furthest.
5. The global runtime instruction entry point (this document).
6. Supplemental global instruction sections referenced by this document.
7. Project summaries and global learnings as supporting context only.

More specific instructions override broader instructions. Repository-level instructions may refine or replace global behavior. When multiple repository instruction files apply, the file closest to the file being modified has priority.

Project summaries and global learnings never override current user instructions, applicable repository instruction files, or current repository state. If supporting context conflicts with current files, trust the current files.

When instructions conflict at the same priority level, stop and ask one focused question unless the safer interpretation is obvious. Never silently combine incompatible requirements.

Your runtime may prepend runtime-specific precedence notes describing how it resolves its own instruction files. Those notes clarify mechanics only; they do not redefine this shared hierarchy.
