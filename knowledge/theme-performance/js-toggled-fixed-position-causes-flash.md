---
symptom: "A sticky/floating bar (e.g. an announcement bar meant to float fixed at the top or bottom of the viewport) briefly renders inline, in normal document flow, at full size — pushing the real header/nav down or overlapping it — before snapping into its correct fixed position a moment after load."
root_cause: "The CSS class that actually applies `position: fixed` was only added by a client-side <script> (querying the element and calling classList.add(...) after computing something else, like a height for a CSS var). Until that script executes, the element sits in normal flow at its DOM position with none of the fixed/floating styling applied, even though all the relevant CSS was already loaded and render-blocking. The flash is 100% JS-timing-dependent, not a missing/async-CSS problem — it happens on every load, on any connection speed, because there is always some gap between first paint and inline-script execution once the browser has more of the DOM to parse first (e.g. the script tag is placed after other markup)."
fix: "Move the class that carries the position:fixed (and any related layout) rules onto an element/class the server-side template already renders unconditionally (e.g. a class already toggled by a Liquid `{% if section.settings.x %}` on the section's own markup), instead of a class added only by JS. Keep JS only for what genuinely needs runtime measurement (e.g. setting a CSS custom property to the element's measured offsetHeight for a sibling to consume) — never for applying positioning that a template setting already knows about at render time. If the newly-targeted selector collides in specificity with an unrelated pre-existing rule that also happens to match the same element (check via `document.styleSheets` + `element.matches(selector)`, not just reading source order), bump specificity deliberately (e.g. repeat the class: `.foo.foo`) rather than reaching for `!important`, and leave a comment naming the exact rule it's beating."
affected_areas: ["sticky/floating header or announcement bars", "any CSS class applied by an inline <script> based on a section setting that Liquid already knows at render time", "critical-CSS setups where a class is in the allow-list but only ever added by JS"]
tags: [fouc, cls, position-fixed, sticky, layout-shift, specificity, critical-css, announcement-bar]
date: 2026-09-18
author: ginthozan
clients_generalized_from: ["connox"]
severity: medium
---

## Symptom

A section meant to float (fixed to the top or bottom of the viewport, e.g. a
dismissible promo/announcement bar) is visible for a moment in the *wrong* place on
every page load: inline, at full width, in normal document flow — typically pushing
the real header/nav/search bar down the page or appearing to overlap other content —
before it "snaps" into its correct floating position a beat later. Looks identical to
a classic FOUC (flash of unstyled content), but disabling network throttling or
confirming the relevant CSS is render-blocking doesn't fix it.

## Root cause

The element's fixed/floating positioning was applied via a CSS class that a
**client-side `<script>` adds after the fact**, not a class the server-side template
renders immediately. A common shape:

```js
// runs late (after JS parses down to this point, or on some deferred trigger)
var el = document.querySelector('[data-thing]');
var wrapper = el.closest('.some-wrapper');
wrapper.classList.add('some-wrapper--sticky'); // <-- this class carries position:fixed
// ...then goes on to measure el.offsetHeight for an unrelated CSS var
```

Until that script runs, the element is laid out exactly as if the setting that should
make it float were off — because from the browser's point of view, it is off, until
JS says otherwise. This has nothing to do with async/deferred CSS: even if every
relevant stylesheet is already fully loaded and parsed, the *class* isn't present yet,
so none of those rules match. The flash is guaranteed on every load, not just slow
connections — it only *looks* like it might be network-dependent because a slower
network makes it easier to notice.

A tell-tale sign when debugging: check `getComputedStyle(el).position` right after
load — if it's `fixed`/`sticky` as expected, inspect whether that came from a class
the template renders unconditionally, or one only present because JS already ran by
the time you checked. Confirm by reading the raw server HTML (`curl` the page, or view
source) and grep for the class name — if it's absent from the raw HTML entirely, it's
JS-added.

## Fix

Find the CSS class that the section's own Liquid/template already renders
unconditionally based on the relevant setting (in this case, a class toggled by
`{% if section.settings.sticky %}` directly in the section's own markup — present in
the very first HTML response, no JS needed). Move the position:fixed (and any other
purely-cosmetic, non-measured styling — border-radius, z-index, etc.) from the
JS-added class onto that one instead. Keep the JS script only for what genuinely
requires a runtime measurement (e.g. `element.offsetHeight` fed into a CSS custom
property that a sibling element consumes for spacing) — delete the `classList.add(...)`
call and whatever DOM lookup existed purely to support it.

**Watch for a specificity collision this can introduce.** If the newly-targeted class
lives on an element that *also* matches some unrelated, pre-existing selector (e.g. a
generic `[data-index="1"]`-style attribute selector used for a completely different
purpose, like giving the first item in a group a stacking context), and that other
rule also sets the same property (commonly `position`), the unrelated rule can win on
specificity regardless of source order — even though the new rule is "more specific to
the bug" conceptually. Don't assume source order decides it; enumerate the actual
matching rules for the element via `document.styleSheets` and filter with
`element.matches(rule.selectorText)` to see what's really being applied and by what.
If there's a genuine collision, deliberately raise specificity (repeating the class,
e.g. `.foo.foo`, is a clear, greppable way to do it) with a comment naming the
colliding selector — don't reach for `!important`, which hides the reason from the
next person who edits either rule.

If the project uses a critical-CSS allow-list (a list of classes that get inlined/
render-blocking so the page paints correctly above the fold before the full stylesheet
loads), double-check the newly-targeted class is already on that list — it likely was,
since JS-added classes still need matching critical CSS to avoid a *second*, separate
FOUC once they're added. Regenerate the critical CSS file after any selector rename.

## Where else this applies

Any "becomes sticky/fixed/floating based on a boolean setting" pattern — cookie
banners, "back in stock" bars, mobile bottom-nav variants, sticky add-to-cart bars —
is worth auditing the same way if it visibly jumps on load: check whether the
positioning class is server-rendered or JS-toggled.

## Related

[[late-dismiss-check-flashes-dismissed-content]] — a second, separate late-JS-flash
bug found on the same element in the same session: that one is about *visibility*
(a dismissed/closed state read from storage) being checked after paint; this one is
about *position*. A sticky **and** dismissible component is worth checking for both.

[[stale-edge-cache-mixes-old-and-new-theme-assets]] — a later bug on the same
sticky-announcement-bar component, in the same client's theme, that looked identical
to a CSS specificity bug but wasn't: the current theme's CSS was already correct, and
the actual cause was a caching service worker serving visitors an old, pre-fix theme
version. Worth ruling that out first before re-diagnosing this one from scratch.
