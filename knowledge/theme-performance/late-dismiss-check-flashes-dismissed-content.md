---
symptom: "An element that should stay hidden after the shopper dismisses it (a promo/announcement bar with an X button, a cookie-style banner, any 'don't show this again' UI backed by sessionStorage/localStorage) still visibly flashes on screen for a moment on every subsequent page load, even though it was dismissed earlier and the storage flag is correctly set — then a script hides it a beat later."
root_cause: "The check that reads the dismissed flag from sessionStorage/localStorage and hides the element lives in a <script> placed AFTER that element's own markup in the DOM (often because the script also needs to wire up the close button's click handler via querySelector, so it was written to run once, after the button exists). A script can only act on markup the parser has already reached — placing the check after the element guarantees the element paints first, in its normal 'not dismissed' state, and only gets hidden once that later script executes. This is unrelated to network speed or async CSS; the storage read itself is effectively instant, but by the time it runs the visible flash has already happened."
fix: "Split the dismiss logic into two scripts: (1) a tiny, synchronous check placed BEFORE the element's markup (as early as possible in that section/component's own template — it doesn't need the element to exist yet) that reads the storage flag and, if dismissed, adds a class to <html> (e.g. `thing-dismissed`); a CSS rule already loaded render-blocking (`html.thing-dismissed [data-thing] { display: none; }`) then prevents the element from ever being visible, because the class lands before the parser even reaches the element. (2) Keep a second script AFTER the element's markup, but strip it down to only what genuinely needs the element to exist: wiring the close button's click handler (which sets the storage flag and hides the element for the current pageview). Don't try to make one script do both jobs — the ordering requirement (before vs. after the markup) is different for each."
affected_areas: ["any dismissible bar/banner/modal backed by sessionStorage or localStorage", "promo/announcement bars", "cookie-consent-style UI that isn't the site's actual CMP", "'seen this before' onboarding tooltips"]
tags: [fouc, dismiss, sessionstorage, localstorage, flash-of-dismissed-content, script-order, critical-css]
date: 2026-09-18
author: ginthozan
clients_generalized_from: ["connox"]
severity: medium
---

## Symptom

A shopper dismisses a bar/banner (clicks an X, it disappears, `sessionStorage` or
`localStorage` remembers that). On their next page load — or any reload — the same
bar visibly reappears for a fraction of a second before disappearing again. It looks
identical to a loading flash (FOUC), and easy to misdiagnose as one, but it happens
even with all CSS already loaded and render-blocking, and even on a fast connection.

Often reported by a user as "there are two banners — one that's always there, and a
temporary one on top that I already closed, but it keeps popping back up for a
second and then hides again."

## Root cause

The dismiss check is correct in *what* it does (reads a storage flag, hides the
element if set) but wrong in *when* it runs. A common shape:

```html
<div data-thing>...</div>
<button data-thing-close>×</button>
<script>
  var el = document.querySelector('[data-thing]');
  if (sessionStorage.getItem('thing_dismissed') === 'true') {
    el.style.display = 'none';
  }
  el.querySelector('[data-thing-close]').addEventListener('click', function () {
    el.style.display = 'none';
    sessionStorage.setItem('thing_dismissed', 'true');
  });
</script>
```

This script is placed after the markup — often simply because it also needs to attach
the click listener, and `querySelector` needs the button to exist first. But that
means the *hide* half of the logic can only run after the browser has already parsed
(and, in practice, often already painted) the element in its default visible state.
The storage read is fast; the problem is purely ordering, not speed.

## Fix

Separate the two concerns, since they have different ordering requirements:

1. **A pre-markup check**, placed directly before the element in the template,
   synchronous, with no DOM dependency other than `document.documentElement`:

   ```html
   <script>
     try {
       if (sessionStorage.getItem('thing_dismissed') === 'true') {
         document.documentElement.classList.add('thing-dismissed');
       }
     } catch (e) {}
   </script>
   <div data-thing>...</div>
   ```

   Pair it with a CSS rule that's already loaded render-blocking (critical CSS /
   inlined `<style>`, not the deferred/async stylesheet):

   ```css
   html.thing-dismissed [data-thing] { display: none; }
   ```

   Because the class is added before the parser even reaches `[data-thing]`, the
   element never has a "visible" frame to flash through.

2. **A post-markup script**, unchanged in position, stripped down to only the click
   handler (which still needs the button to exist):

   ```html
   <script>
     document.querySelector('[data-thing-close]').addEventListener('click', function () {
       document.querySelector('[data-thing]').style.display = 'none';
       try { sessionStorage.setItem('thing_dismissed', 'true'); } catch (e) {}
     });
   </script>
   ```

Don't try to keep this as one script — the two halves genuinely need to run at
different points in the parse, and combining them is what caused the bug.

If the project has a critical-CSS allow-list/build step, make sure the new class
(`thing-dismissed` here) is on it and regenerate — otherwise this fix just trades a
"flash before hide" bug for a "flash before critical CSS loads" one.

## Where else this applies

Any component with a "remember that the shopper closed/saw this" behavior driven by
`sessionStorage`/`localStorage` and a script that both checks the flag and wires up
the close button in one place, positioned after the component's markup. Cookie-style
banners that aren't the site's real consent-management platform, first-visit
tooltips, "new feature" callouts, dismissible free-shipping bars — all the same
shape.

## Related

[[js-toggled-fixed-position-causes-flash]] — a different late-JS-flash bug found on
the same element in the same session: that one was about *position* (fixed vs. normal
flow) being JS-toggled after paint; this one is about *visibility* (dismissed state)
being JS-checked after paint. Worth checking both on any sticky+dismissible component.
