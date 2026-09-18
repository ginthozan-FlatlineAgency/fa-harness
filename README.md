# flatline-shopify-kit

Shared, git-versioned memory for Flatline's Shopify work. This is **not** a client
theme or app — it's a plain local folder of Claude Code skills, an agent, and a
knowledge base, symlinked into `~/.claude` so it's available in every client repo
(Liquid/Horizon themes, checkout/POS extensions, custom apps) without installing
anything, so that a fix made once in any one project is reusable in all the others,
and so the team can share and review new knowledge via ordinary git PRs instead of
it living only in one person's chat history.

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

No install step. Claude Code auto-loads skills/agents/commands from `~/.claude/`
globally, so this repo's `skills/`, `agents/`, and `commands/` are symlinked in:

```bash
ln -s ~/Developer/flatline-shopify-kit/skills/search-knowledge ~/.claude/skills/search-knowledge
ln -s ~/Developer/flatline-shopify-kit/skills/log-fix           ~/.claude/skills/log-fix
ln -s ~/Developer/flatline-shopify-kit/agents/knowledge-scout.md ~/.claude/agents/knowledge-scout.md
ln -s ~/Developer/flatline-shopify-kit/commands/log-fix.md       ~/.claude/commands/log-fix.md
```

Once linked, `search-knowledge`, `/log-fix`, and the `knowledge-scout` subagent are
available in **every** Claude Code session on that machine — every client repo,
automatically, with nothing to install or run per-project.

`~/Developer/CLAUDE.md` (not committed here — it's per-machine, since `~/Developer`
isn't itself a repo) is what points agents at this repo by convention; Claude Code
loads it automatically via its directory walk-up whenever you're working inside any
client repo underneath `~/Developer`.

A teammate wanting the same setup just `git clone`s this repo into their own
`~/Developer` and creates the same 4 symlinks — no plugin or marketplace involved.

## Knowledge entry format

See `AGENTS.md` for the full schema and — most importantly — the guardrails on what
must never appear in an entry (client secrets, URLs, keys, raw proprietary code).

## Status

Phase 1 (see the plan this was built from): manual grep-based search, manual
`/log-fix` capture, one retrieval subagent. No auto-triggering, no hooks, no remote
yet — deliberately minimal until the workflow is proven and habitual.
