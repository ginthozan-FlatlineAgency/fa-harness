---
symptom: "Field CLS (CrUX / PageSpeed Insights mobile) reports a poor layout-shift score despite a low desktop Lighthouse lab CLS; below-the-fold sections appear to snap to full height all at once on first scroll/interaction on mobile."
root_cause: "Below-the-fold sections use `content-visibility: auto` gated behind a `[data-initializing]` attribute on <body>, stripped by JS on the first mouseover/scroll/keydown/touch event (or a timer fallback). Removing that one attribute makes the whole CSS rule stop matching for every still-collapsed section at once, so they all revert from their placeholder height to full height in a single synchronous layout batch instead of progressively as each one scrolls into view. Since scrolling is itself a trigger, the snap can happen while content is on-screen for a real user."
fix: "Remove the [data-initializing] gate entirely so content-visibility: auto applies permanently from load. Each section then reveals individually via the browser's own native scroll-driven behavior instead of one shared trigger reverting everything at once."
affected_areas: ["theme.css", "theme.js", "layout/theme.liquid", "critical.css"]
tags: [cls, content-visibility, layout-shift, performance, core-web-vitals]
date: 2026-09-07
author: ginthozan
clients_generalized_from: ["connox"]
severity: high
---

## Symptom
Field CLS (CrUX / PSI mobile) is poor (e.g. red, 0.5+) even though desktop Lighthouse
lab CLS looks fine (e.g. 0.002). Desktop Lighthouse never scrolls or interacts with
the page, so it structurally cannot see this class of bug — always check field data
(CrUX/PSI mobile), not just a lab run, when investigating a CLS complaint.

## Root cause
A common lazy-render optimization gates `content-visibility: auto` on below-the-fold
sections behind an attribute like `[data-initializing]` on `<body>`, removed by JS on
the first `mouseover`/`scroll`/`keydown`/`touchstart` (or a fallback timer). The
intent is "render lazily, then let the browser take over" — but removing one
attribute makes the *entire* CSS rule stop matching in one step. Every section still
off-screen and still collapsed to its placeholder height reverts to its real (often
much taller) height in one synchronous batch. Widening the placeholder height
estimate (e.g. via `contain-intrinsic-size`) only reduces the *aggregate*
height-estimate error — it does not fix the batched-reveal mechanism, so CLS stays
high.

## Fix
```css
/* Before: gated — first interaction reverts every section at once */
[data-initializing] .lazy-section { content-visibility: visible; }
.lazy-section { content-visibility: auto; contain-intrinsic-size: auto 600px; }

/* After: no gate — browser reveals each section natively as it nears viewport */
.lazy-section { content-visibility: auto; contain-intrinsic-size: auto 600px; }
```
Also remove the JS that strips `[data-initializing]` on first interaction, once
confirmed nothing else in the codebase depends on that attribute for an unrelated
purpose.

## How to verify
Lab tools (desktop Lighthouse) won't reproduce this. Simulate a real scroll/mousemove
on a *mobile* viewport against a live preview and confirm sections reveal
progressively, not all at once. Final confirmation needs a real deploy plus a PSI
mobile / CrUX field re-check — field CLS lags actual traffic and can't be verified
synchronously in a browser automation tool.

## Where else this applies
Any theme using `content-visibility: auto` for below-the-fold lazy rendering combined
with an attribute-based "stop being lazy after first interaction" gate. If the gate
is JS-attribute-based rather than relying on the browser's native per-element
visibility, suspect the same batched-reveal failure mode.
