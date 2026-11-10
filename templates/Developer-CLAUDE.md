# ~/Developer

Layout: one folder per client (`connox/`, `oger/`, `matrabike/`, `wolplein/`, `jhp/`,
`tricorp/`, `8848/`), `flatline/` for agency-owned products, and `fa-harness/` for the
shared tooling. Each repo inside is an independent Shopify store or app — do not assume
shared git history, ownership, or secrets across them. Jump to one with `dev <name>`.

## Harness (`fa-harness/`)

- `fa-harness/flatline-shopify-kit/` — **shared** knowledge base + skills/agent/commands
  (git-versioned, installed into `~/.claude` by `scripts/setup.sh`).
- `fa-harness/memory/` — **personal** client/relationship notes. Never shared.

Before deep-diving into a bug in any project here, use the `search-knowledge` skill
(or the `knowledge-scout` agent) to check whether it has already been solved elsewhere.
At the end of a session that produced a reusable fix, run `/log-fix` — it writes into
`fa-harness/flatline-shopify-kit`, never into the client repo you were working in. For a
client contact/decision/preference, use `/remember` (goes to `fa-harness/memory`).

Never put client secrets, store URLs, API keys, customer data, or raw proprietary code
into a `flatline-shopify-kit` entry — see its `AGENTS.md`. `scripts/kb.py lint` and the
pre-commit hook enforce this.

## Config precedence

This file is loaded for every repo under `~/Developer`. A repo's own `CLAUDE.md` /
`AGENTS.md` adds to it and wins on conflicts for that repo; it should not restate these
conventions. A repo's `.claude/settings.local.json` is that repo's own permissions only
(machine-local, not shared). Repo-level CLAUDE.md files that just say `@AGENTS.md` are
fine — put repo-specific rules in the AGENTS.md they import.

## New machine

`git clone` the kit into `~/Developer/fa-harness/`, then run
`fa-harness/flatline-shopify-kit/scripts/setup.sh`.
