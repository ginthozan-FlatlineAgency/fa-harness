---
symptom: "A client/CMP integration reports that Shopify's Customer Privacy API (marketingAllowed()/analyticsProcessingAllowed()) returns true even though the region is under enforced GDPR and the visitor has made no consent decision yet (getTrackingConsent() reports 'no_interaction'), despite the theme's CMP bridge script working correctly and correctly flipping the flags to false on an explicit denial."
root_cause: "This is a real behavior of Shopify's own Customer Privacy API, not a bug in the theme's CMP bridge. In the window between page load and the moment the actual CMP (Usercentrics, OneTrust, etc.) dispatches its consent-decision event, Shopify.customerPrivacy.marketingAllowed()/analyticsProcessingAllowed() can report true even under isRegulationEnforced() === true for GDPR — it's a permissive default before any decision is recorded, not something the theme's bridge script sets. A repo-wide search confirming setTrackingConsent() is called from exactly one place (the CMP bridge), and that it hadn't fired yet in the failing state, is what proves the bridge script isn't the cause."
fix: "There is no theme-side fix for the pre-interaction default itself — it's an Admin -> Settings -> Customer Privacy configuration behavior (how the shop delegates consent to a partner/custom CMP), not something a Liquid/JS bridge script can override before the CMP has actually run. Confirm the bridge script correctly flips both flags on a REAL explicit denial (dispatch the actual consent-denied event through the live code path, not just static source inspection) to rule out the bridge, then explain the pre-interaction window back to whoever reported it rather than chasing a non-existent regression in the bridge code."
affected_areas: ["Shopify Customer Privacy API", "CMP/consent bridge scripts", "GDPR/regional consent handling"]
tags: [consent, gdpr, customer-privacy-api, cmp, ga4, false-positive]
date: 2026-08-06
author: ginthozan
clients_generalized_from: ["connox"]
severity: medium
---

## Symptom
A stakeholder reports "consent defaults to allowed even under GDPR" after a CMP
bridge fix ships. It looks like a regression in the fix, but on a genuinely fresh
session (cleared cookies/localStorage) `getTrackingConsent()` reports
`"no_interaction"` — meaning no consent decision has been recorded by anyone yet —
while `marketingAllowed()`/`analyticsProcessingAllowed()` already report `true`
under `isRegulationEnforced() === true` for GDPR.

## Root cause
Shopify's own Customer Privacy API is permissive by default in the window before
any CMP decision is recorded, regardless of detected regulation. This is platform
behavior, not something introduced by a theme's bridge script. Two things can look
identical from the outside but have different causes:
1. **A real dead bridge** — the CMP's own consent-decision event schema changed
   (e.g. a nested `.services` array vs. flat booleans) and the bridge's
   `setTrackingConsent()` call never fires at all. This IS a theme-side bug.
2. **The pre-interaction default** — the bridge works fine and does fire on a real
   decision, but *before* that decision exists, the platform API is already
   reporting permissive values. This is NOT a theme-side bug.

## How to tell them apart
Don't infer from source inspection alone — trigger a REAL consent-denied event
through the actual live code path (e.g. dispatch the CMP's own event with a denied
payload) and confirm `marketingAllowed()`/`analyticsProcessingAllowed()` flip to
`false` and `getTrackingConsent()` changes from `"no_interaction"` to `"no"`. If
that works, the bridge itself is fine — the report is about the pre-interaction
window, which is a Shopify Admin Customer Privacy setting question, not a code fix.

## Fix / what to tell the reporter
- Confirm via the live-event test above that the bridge correctly responds to an
  explicit decision.
- Explain that the `true`-by-default they're seeing is Shopify's own API being
  permissive pre-interaction, not a regression — ask them to specify *when* they're
  reading the value (immediately on load vs. after actually clicking Deny in the
  CMP's own banner), since those are two different situations that look identical
  in a bug report.
- If they specifically need deny-by-default in that pre-interaction window, that's
  an Admin -> Settings -> Customer Privacy configuration question on their side
  (how the shop is set up to delegate consent to a partner/custom CMP), not
  something fixable in `snippets/*consent*.liquid`.

## Where else this applies
Any Shopify theme integrating a third-party CMP (Usercentrics, OneTrust, Cookiebot,
etc.) via `Shopify.customerPrivacy`. Expect this exact "false regression report" to
recur with every new CMP integration or every stakeholder who tests consent state
immediately on page load instead of after an explicit decision.
