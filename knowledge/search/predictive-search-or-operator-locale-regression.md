---
symptom: "Predictive/storefront search for multi-variant SKU-style queries (e.g. zero-padding variants of an article code) returns correct results on one storefront locale and zero or fewer results on another, with byte-identical query strings and no recent theme changes on either side."
root_cause: "A theme-side search enhancement rewrote a query into an OR chain across variants (e.g. '000619 OR 0000619 OR 00000619') to paper over inconsistent zero-padding. Shopify's storefront search backend changed, on a subset of locales, from treating OR as a boolean union operator to treating it as a literal search token — turning the query into an implicit intersection. Every extra OR branch then shrinks the result set instead of growing it (result counts drop as branches are added, including degenerate cases like 'X OR X' returning fewer results than 'X' alone). This is a platform-side search-engine change, not a theme regression — detectable because the theme sends the exact same query string on every locale and only some locales are affected."
fix: "Stop relying on boolean search operators in theme-side query construction entirely. Replace the OR-chain with a single, pre-resolved term: pad the query to the known article-code length and preflight it against the store's own search-suggest endpoint before using the padded form, falling back to the term as typed if the padded form has no matches. Locale-independent, and doesn't depend on the search backend's operator semantics at all."
affected_areas: ["predictive-search.js", "main-search.liquid", "settings_schema.json"]
tags: [search, predictive-search, or-operator, locale, sku, platform-change]
date: 2026-09-01
author: ginthozan
clients_generalized_from: ["interbosch"]
severity: medium
---

## Diagnosing this class of bug
The tell: same query string, same catalog, same theme code — only the storefront
*locale* differs in outcome, and adding more OR branches makes the result count go
DOWN, not up (a true union could never return fewer results than its first branch
alone). That pattern means the backend is intersecting, not unioning — a platform
change, not something to chase in the theme's own code.

## Fix
```js
// Instead of building "termA OR termB OR termC":
async function resolveSkuTerm(rawQuery, articleCodeLength) {
  if (!/^\d+$/.test(rawQuery) || rawQuery.length >= articleCodeLength) return rawQuery;
  const padded = rawQuery.padStart(articleCodeLength, "0");
  const hasMatch = await checkSuggestEndpoint(padded); // single term, no boolean operator
  return hasMatch ? padded : rawQuery;
}
```
Cache resolved terms per input; skip the check entirely for already-full-length or
non-numeric queries so the common path adds no extra request.

## Where else this applies
Any theme customization that constructs a storefront search query using OR/AND
operators for variant or synonym expansion. Treat Shopify's storefront search
operator behavior as something that can change without any theme-side commit, and
prefer resolving to a single well-formed term over relying on boolean semantics
wherever that's an option.
