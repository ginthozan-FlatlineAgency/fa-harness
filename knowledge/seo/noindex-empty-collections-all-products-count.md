---
symptom: "SEO audit / crawl-budget review flags Shopify collection pages with 0 products as indexable (200, no noindex), including collections that are only temporarily out of stock."
root_cause: "The intuitive Liquid property for 'is this collection empty', collection.products_count, is actually the count AFTER the currently-applied storefront filters — not the collection's true size. collection.all_products_count is the unfiltered count. Gating noindex on products_count == 0 also noindexes any URL where the applied filter combination matches nothing (a colour/size filter with no stock), which is routine on stores with faceted filtering, not an edge case."
fix: "Gate the noindex meta tag on collection.all_products_count == 0, not collection.products_count == 0, and fold it into whatever pagination/robots logic already exists rather than adding a second parallel {% if %} block — in Liquid 0 is truthy, so an out-of-range page number and a genuinely-empty collection can both trip separate blocks and double-emit the tag."
affected_areas: ["layout/theme.liquid", "collection templates"]
tags: [seo, noindex, collections, liquid, all_products_count, crawl-budget]
date: 2026-09-04
author: ginthozan
clients_generalized_from: ["connox"]
severity: medium
---

## Symptom
An SEO/crawl-budget review flags empty Shopify collections as fully indexable. The
"obvious" Liquid fix (`collection.products_count == 0`) looks right in isolation but
is subtly wrong once storefront filtering is involved.

## Root cause
`products_count` is post-filter; `all_products_count` is the real collection size.
Any theme with facet/filter UI (colour, size, price range, etc.) will regularly
produce filtered URLs where `products_count` is 0 even though the collection itself
has hundreds of products — using the filtered count as the noindex signal would
noindex those healthy, filtered pages too.

## Fix
```liquid
{%- comment -%} Merge into the existing pagination/robots block, don't add a second one {%- endcomment -%}
{%- assign should_noindex = false -%}
{%- if paginate.pages > 0 and paginate.current_page > paginate.pages -%}
  {%- assign should_noindex = true -%}
{%- elsif collection.all_products_count == 0 -%}
  {%- assign should_noindex = true -%}
{%- endif -%}
{%- if should_noindex -%}
  <meta name="robots" content="noindex, follow">
{%- endif -%}
```

## Related decision: noindex vs. unpublish
A collection that empties out can also be handled by unpublishing it from the Online
Store sales channel — but the two solve different problems:
- **noindex** is instant (applied the moment the theme renders) and market-scoped
  (since `all_products_count` is per-market). Best for collections that cycle
  between empty and stocked.
- **Unpublish** removes the URL from the sitemap entirely — something a theme cannot
  do on its own, since the sitemap is Shopify-generated, not a theme file — but it's
  a batched admin operation with a lag window in both directions (empty→unpublish and
  restocked→republish). Best for collections that are dead for good.
Use noindex as the always-on, zero-latency net; use unpublish for the ones that
genuinely aren't coming back.

## Where else this applies
Any Online Store 2.0 theme doing collection-emptiness checks for SEO, redirects, or
empty-state logic. Grep for bare `products_count` (without `all_`) as a red flag —
the theme's own filter-count UI copy (e.g. "showing 12 of 512") is usually the only
legitimate use of the filtered count.
