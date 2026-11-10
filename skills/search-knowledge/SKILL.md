---
name: search-knowledge
description: Search the flatline-shopify-kit knowledge base for a prior fix before researching a Shopify/Liquid/checkout-extension/POS/deploy problem from scratch. Use at the START of any bug investigation, error message, or "why doesn't X work" question in a Shopify theme or app repo.
---

Before doing any fresh exploration of a Shopify bug:

1. Extract 3-6 keywords from the symptom (error text, feature area, API/file name,
   e.g. "checkout extension env var null", "CLS mobile", "noindex collection").
2. Search the shared knowledge base:
   ```
   grep -ril -e "<keyword1>" -e "<keyword2>" ~/Developer/fa-harness/flatline-shopify-kit/knowledge
   ```
   and cross-check `~/Developer/fa-harness/flatline-shopify-kit/knowledge/INDEX.md` for matching tags.
3. If a matching entry exists: read it in full, adapt the fix to the current repo
   (file paths and specifics will differ client to client), and say in your response
   which knowledge entry you used.
4. If nothing matches closely: say so explicitly, then proceed with normal
   exploration. Once resolved, use the `log-fix` skill (`/log-fix`) to capture it —
   don't let it disappear into this session's history the way it did before this
   knowledge base existed.

Do not treat a partial keyword overlap as a confirmed match — skim the entry's
`root_cause` before assuming it's the same bug; Shopify bugs with similar symptoms
often have different causes (e.g. two different "search returns fewer results"
issues can be a platform search-engine change vs. a theme-side filter bug).
