---
symptom: "A custom Shopify app's embedded admin UI shows a blank/placeholder iframe or console errors about a wrong/placeholder origin, even though the app's hosting platform shows the latest deployment as healthy and shopify.app.toml has the correct application_url."
root_cause: "Shopify admin renders the embedded app iframe's src from the currently RELEASED app version on Shopify's side — not from whatever shopify.app.toml says in the repo, and not from what's deployed on the hosting platform. shopify.app.toml is inert until pushed via `shopify app deploy`/release. If an old app version (from before a URL fix) is still the released one, the admin keeps loading the stale URL indefinitely, no matter how many times the hosting platform redeploys."
fix: "After fixing application_url (or any config in shopify.app.toml), explicitly deploy AND release a new Shopify app version (shopify app deploy, or the CI equivalent) — a correct toml file or a green hosting-platform deploy does not mean Shopify's side is updated. Separately: if automatically_update_urls_on_dev = true is set on the production config, running shopify app dev will silently overwrite the production application_url with a local dev tunnel URL — use a separate dev-only toml instead of running dev against the production config."
affected_areas: ["shopify.app.toml", "shopify app deploy", "embedded app iframe"]
tags: [deploy-cli, shopify-app-toml, released-version, application_url, embedded-app]
date: 2026-08-27
author: ginthozan
clients_generalized_from: ["oger"]
severity: high
---

## Symptom / root cause
See frontmatter. The core trap: hosting-platform deploy success and a correct repo
file are both necessary but NOT sufficient — Shopify's own release step is a
separate, easy-to-forget gate in front of what the admin actually loads.

## Fix checklist when an embedded custom app shows the wrong/placeholder origin
1. Check the *released* Shopify app version, not just the repo or hosting platform:
   `shopify app versions list`.
2. If the active version predates the URL fix, run `shopify app deploy` (and
   release) to publish a new version with the corrected `application_url`.
3. Check `automatically_update_urls_on_dev` in the production `shopify.app.toml` — if
   `true`, any `shopify app dev` run against that config can silently clobber the
   production URL with a tunnel URL. Use a separate dev-only toml.
4. Also check `redirect_urls` matches the app's actual OAuth callback route (a
   mismatched prefix leaves the callback with nowhere valid to land) — a related,
   easy-to-miss cause of the same "embedded app doesn't load" symptom.

## Where else this applies
Any custom Shopify app (not a theme) where hosting-platform deploy success is being
used as the signal that "the app is updated." The Shopify-side release step is
always a separate gate that has to be checked on its own.
