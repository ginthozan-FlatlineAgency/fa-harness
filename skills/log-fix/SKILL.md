---
name: log-fix
description: Capture the fix just applied in this session as a new generalized knowledge-base entry in flatline-shopify-kit. Use at the end of a debugging session that resolved a Shopify bug worth reusing elsewhere, typically via the /log-fix command.
---

Run this after a bug is actually resolved and verified — not mid-investigation.

1. Summarize from the conversation: `symptom`, `root_cause`, `fix` (one line each),
   and pick `affected_areas`/`tags` that describe the *pattern*, not this client's
   specific files.
2. **Strip before writing anything**: store domains/URLs, API keys/tokens/secrets,
   customer data, and raw copy-pasted client code. Rewrite code snippets as a
   generalized pattern. If a detail can't be generalized without losing the point,
   leave it out rather than include it verbatim — see the guardrails in this repo's
   `AGENTS.md`.
3. Pick (or create) a category under `~/Developer/flatline-shopify-kit/knowledge/<category>/`
   and a kebab-case slug. Write `<slug>.md` following the schema in `AGENTS.md`
   (in that same repo).
4. Add one row to `~/Developer/flatline-shopify-kit/knowledge/INDEX.md`.
5. Show the user `git -C ~/Developer/flatline-shopify-kit status`/`diff` for the new
   file and remind them to review, commit, and (once this repo has a remote)
   push/PR it from the **flatline-shopify-kit** repo — never write the entry into
   the client repo you were just working in.

This is deliberately something a human triggers and reviews before it's committed —
not a background auto-writer.
