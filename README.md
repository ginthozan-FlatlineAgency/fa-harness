# flatline-shopify-kit

Shared, git-versioned memory for Flatline's Shopify work. This is **not** a client
theme or app — it's a standalone Claude Code plugin, meant to be installed into every
client repo (Liquid/Horizon themes, checkout/POS extensions, custom apps) so that a
fix made once in any one project is reusable in all the others, and so the team can
share and review new knowledge via ordinary git PRs instead of it living only in one
person's chat history.

## Why this exists

Recurring Shopify bugs (a11y/perf gotchas, esbuild env-var quirks in checkout
extensions, Shopify-CLI deploy footguns, locale-specific search regressions...) used
to get fixed once in a Claude Code chat and then forgotten — the same problem could
resurface in a different client's repo and need re-researching from scratch. This
plugin turns each resolved fix into a small, generalized, git-diffable markdown file
that any agent (or human) can grep before starting fresh research.

## Structure

```
knowledge/<category>/<slug>.md   real fix entries — see FORMAT below
knowledge/INDEX.md               tag/category lookup table
skills/search-knowledge/         use BEFORE researching a new bug
skills/log-fix/                  use AFTER resolving one, to capture it
commands/log-fix.md              /log-fix slash command wrapper
agents/knowledge-scout.md        cheap-model (haiku) retrieval-only subagent
```

## Using it in a client repo

Once this is pushed to a real git remote and registered as a marketplace:

```bash
claude plugin marketplace add <org>/flatline-shopify-kit
claude plugin install flatline-shopify-kit@flatline-shopify-kit
```

Until then, this is a local-only repo — see `~/Developer/AGENTS.md` for the
per-machine pointer that tells agents working in any client repo to reach for
`search-knowledge` first and `/log-fix` after.

## Knowledge entry format

See `AGENTS.md` for the full schema and — most importantly — the guardrails on what
must never appear in an entry (client secrets, URLs, keys, raw proprietary code).

## Status

Phase 1 (see the plan this was built from): manual grep-based search, manual
`/log-fix` capture, one retrieval subagent. No auto-triggering, no hooks, no remote
yet — deliberately minimal until the workflow is proven and habitual.
