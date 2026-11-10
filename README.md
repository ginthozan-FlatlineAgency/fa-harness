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
knowledge/INDEX.md               generated tag/category lookup (scripts/kb.py index)
skills/search-knowledge/         use BEFORE researching a new bug
skills/log-fix/                  use AFTER resolving one, to capture it
skills/prisma-postgres-setup/    vendored from github.com/prisma/skills — provision a
                                 Prisma Postgres DB via the Management API
commands/log-fix.md              /log-fix slash command wrapper
agents/knowledge-scout.md        cheap-model (haiku) retrieval-only subagent
scripts/setup.sh                 one-shot, idempotent per-machine install
scripts/kb.py                    `index` (regenerate INDEX.md) and `lint` (schema + guardrails)
scripts/hooks/pre-commit         runs lint + index check on every commit (enabled by setup.sh)
scripts/dev.zsh                  `dev <name>` shell shortcut to jump to any repo
templates/Developer-CLAUDE.md    the ~/Developer/CLAUDE.md that points agents here
```

## Where it lives

```
~/Developer/
  CLAUDE.md -> fa-harness/flatline-shopify-kit/templates/Developer-CLAUDE.md
  fa-harness/
    flatline-shopify-kit/   this repo (shared)
    memory/                 personal client notes — separate repo, never shared;
                            adds /remember and search-memory skills
  connox/ oger/ matrabike/ wolplein/ jhp/ tricorp/ 8848/   one folder per client
  flatline/                 agency-owned products
```

## Install (new machine)

```bash
git clone <this repo> ~/Developer/fa-harness/flatline-shopify-kit
~/Developer/fa-harness/flatline-shopify-kit/scripts/setup.sh
```

`setup.sh` symlinks every skill, agent and command into `~/.claude` (plus the personal
`memory` skills if that folder exists), links the root `CLAUDE.md`, enables the
pre-commit hook, and adds the `dev` shortcut to `~/.zshrc`. Claude Code then loads
all of it in every client repo underneath `~/Developer` — nothing to install per repo.

## Everyday use

- `dev conn` — cd into the unique repo matching "conn" (`dev` alone lists all).
- Hit a bug → `search-knowledge` skill / `knowledge-scout` agent first.
- Fixed something reusable → `/log-fix`, review the diff, commit from this repo.
- `scripts/kb.py lint` and `scripts/kb.py index` run automatically on commit.

## Knowledge entry format

See `AGENTS.md` for the full schema and — most importantly — the guardrails on what
must never appear in an entry (client secrets, URLs, keys, raw proprietary code).

## Status

Phase 1 (see the plan this was built from): manual grep-based search, manual
`/log-fix` capture, one retrieval subagent. No auto-triggering, no hooks, no remote
yet — deliberately minimal until the workflow is proven and habitual.
