---
symptom: "A sticky/pinned element (header, announcement bar, etc.) visibly misbehaves for real visitors — a gap opens up, an element fails to stay pinned, a fix that was already shipped appears to 'not be working' — even though the current theme code and CSS look completely correct on inspection, and the bug can't be reproduced by reading the code or diffing recent commits."
root_cause: "A full-page caching/performance service worker (e.g. Baqend Speed Kit, or any similar edge-cache/service-worker app that pre-renders and serves cached page shells) served a page snapshot captured against an OLDER theme version, then live-patched only specific 'dynamic blocks' (header markup, cart count, etc.) with fresh HTML/JS from the CURRENTLY published theme — without refreshing the cached shell's <head> (critical.css/theme.css links). The result: two different theme asset versions load on the same page at once (two full sets of versioned asset URLs, e.g. /cdn/shop/t/<old-id>/... and /cdn/shop/t/<new-id>/...). Old and new CSS rules of equal specificity for the same selectors fight it out in the cascade, and whichever the cached (stale) stylesheet's rule happens to be can silently override a fix that was already correctly deployed. Fetching the same URL directly from the platform origin with cache disabled (bypassing the service worker) shows only the current theme's assets and confirms the live theme is fine — the bug only reproduces through the cache/service-worker layer."
fix: "Not a theme-code fix. (1) Confirm the diagnosis: check document.styleSheets / <link>/<script> tags in a live browser session for more than one distinct theme-asset version path; fetch the page with `fetch(url, {cache: 'reload'})` and check the response for only one theme-asset version and no service-worker-only markers — if that response is clean, the published theme is correct and the problem is entirely in the caching layer. (2) Purge/invalidate the caching app's cache for the affected store (its own dashboard, or ask whoever manages that integration) so it re-crawls against the current theme. (3) Where possible, wire automatic cache invalidation into the deploy pipeline so every theme push forces a fresh crawl/cache-bust, instead of relying on manual purges after the fact. (4) If the caching app supports scoping 'dynamic blocks' (fragments it refreshes live instead of serving from the cached shell), check whether the affected component's dependent CSS/JS is actually included in that scope — a dynamic block that swaps in fresh markup but not its stylesheet is exactly what causes this split."
affected_areas: ["full-page caching / service-worker performance apps (Speed Kit, similar edge-cache tools)", "sticky header / announcement bar CSS", "critical.css and theme.css asset versioning", "deploy pipeline cache invalidation"]
tags: [cdn-cache, service-worker, stale-cache, speed-kit, baqend, theme-versioning, sticky-header, false-positive, dynamic-block]
date: 2026-09-21
author: ginthozan
clients_generalized_from: ["connox"]
severity: high
---

## Symptom

A shopper-facing layout bug — most often something involving a sticky/pinned element
(a header that leaves a gap above it while scrolling, an announcement bar that stops
staying fixed, a CLS fix that seems to have "stopped working") — that cannot be
reproduced by reading the theme's source code, diffing recent commits, or reviewing
the CSS specificity by hand. The relevant fix may already be correctly present in the
current theme files. The bug is real for real visitors, but looks like a ghost when
investigated purely as a code-review problem.

## Root cause

A full-page caching/performance app that installs a service worker (Baqend Speed Kit
is the concrete case this was found in, but any similar edge-cache/pre-render tool
follows the same shape) serves visitors a **cached page shell captured from an older
theme version**. To keep genuinely dynamic content fresh, these tools typically
support "dynamic block" replacement — swapping specific fragments (a header, cart
count, personalization) with live-fetched markup from the *currently published*
theme, while leaving the rest of the cached shell (including its `<head>`, and
therefore its `critical.css`/`theme.css` `<link>` tags) untouched.

The failure mode: the live-patched fragment pulls in JavaScript from the current
theme (e.g. a header custom element), but the page's actual active stylesheets are
still the *old*, cached theme version's `critical.css`/`theme.css`. If both old and
new stylesheets end up loaded together (old one from the cached shell, new one
fetched incidentally by the dynamic-block patch but not necessarily *applied* as an
active stylesheet), a same-specificity CSS rule that was already fixed in the current
theme can still lose to the old theme's version of that rule, because the old
stylesheet is what's actually active in `document.styleSheets`.

Concretely, in the case this was found: a sticky header positioned itself relative to
an announcement bar's height via a CSS custom property, assuming the announcement bar
stayed `position: fixed`. The *current* theme's CSS already contained the correct,
higher-specificity rule to keep it fixed. But visitors were being served a cached
shell built against an older theme version that lacked that rule, so the announcement
bar fell back to `position: relative` and scrolled away normally — while the header
still reserved space for it, producing a visible gap.

## Fix

This is a caching/infrastructure issue, not something to patch in the theme:

1. **Confirm before touching any code.** In a real browser session on the live site,
   list every `<link>`/`<script>` tag whose URL contains a versioned theme-asset path
   (e.g. Shopify's `/cdn/shop/t/<theme_id>/assets/...`). If more than one distinct
   `<theme_id>` shows up on the same page load, that's the signature. Cross-check by
   fetching the same URL directly, bypassing the cache:
   ```js
   const res = await fetch(location.href, { cache: 'reload' });
   const html = await res.text();
   // count occurrences of each theme_id's asset path in the raw response
   ```
   If that direct-from-origin response only references the current theme (and the
   response's own cache-status header/timing shows it came from the platform, not an
   edge cache), the published theme is clean and the bug is 100% in the caching
   layer — stop looking at the theme code.
2. **Purge the caching app's cache** for the store (its own dashboard, or ask whoever
   owns that integration) so it re-crawls against the current theme.
3. **Wire cache invalidation into the deploy pipeline** if it isn't already, so every
   theme push triggers a purge/re-crawl automatically instead of depending on someone
   remembering to do it manually after each deploy.
4. **Check the dynamic-block scope.** If the caching app lets you define which
   fragments get live-refreshed vs. served from the cached shell, verify the
   fragment causing the visible bug also has its dependent CSS/JS in scope — a
   fragment refreshed without its stylesheet is exactly this bug.

## Where else this applies

Any store running a full-page caching/performance service worker (Speed Kit or
similar) is worth checking this way *first* whenever a layout bug "shouldn't be
possible" given the current theme code — especially anything involving sticky/fixed
positioning, CLS, or a fix that was recently shipped but still seems to intermittently
fail for real users while looking fine in every direct preview/dev-theme check.

## Related

[[js-toggled-fixed-position-causes-flash]] — a different bug on the same class of
component (sticky announcement bar / CSS specificity), found in the same client's
theme code rather than its caching layer. Worth checking both: first rule out a stale
edge cache serving old assets (this entry), then check for JS-timing/specificity
issues in the current theme's own code (that entry).
