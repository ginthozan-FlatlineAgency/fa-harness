# Working on flatline-shopify-kit itself

This repo IS the shared knowledge base — read this before adding or editing anything
under `knowledge/`.

## Knowledge entry schema

`knowledge/<category>/<slug>.md`, YAML frontmatter + markdown body:

```yaml
---
symptom: "what was observed, in plain terms"
root_cause: "why it actually happens"
fix: "one-line summary of the fix"
affected_areas: ["file/area names, generic"]
tags: [lowercase, kebab-or-single-words]
date: YYYY-MM-DD
author: <agency username>
clients_generalized_from: ["client-name-only, never more"]
severity: low | medium | high
---
```
Body: `## Symptom`, `## Root cause`, `## Fix` (with a generalized code snippet where
useful), optionally `## Where else this applies`.

Categories are not fixed — add a new one under `knowledge/` when a fix doesn't fit an
existing category. Current ones: `theme-performance`, `seo`, `checkout-extensions`,
`search`, `deploy-cli`.

## Guardrails — enforce every time, no exceptions

This repo is installed into **every** client engagement. Anything committed here is
effectively visible across all of them. Before writing or approving any entry, check
it contains none of:

- Store domains, myshopify.com subdomains, or any live URL
- API keys, tokens, secrets, webhook signing secrets
- Customer PII or order data
- Raw copy-pasted client code — write a **generalized pattern** instead, not a diff
  lifted from the client repo
- Client names anywhere except the optional `clients_generalized_from:` frontmatter
  list (names only, never enough detail to identify their stack/business specifics)

When this repo has a real git remote and team members: every new entry goes through
a PR, reviewed by someone other than the author, specifically for the guardrails
above — not solo-merged, even by the person who owns the client relationship.

## Maintaining INDEX.md

`knowledge/INDEX.md` is generated — never edit it by hand. After adding or changing an
entry run `scripts/kb.py index`; `scripts/kb.py lint` checks the schema and guardrails.
Both run in the pre-commit hook (installed by `scripts/setup.sh`), so a commit with a
stale index or a leaked URL/secret/client name is rejected.

Body requirement: a `## Symptom`/`## Root cause` (or `## Diagnosing…`) section and a
`## Fix` section; other sections are optional.
