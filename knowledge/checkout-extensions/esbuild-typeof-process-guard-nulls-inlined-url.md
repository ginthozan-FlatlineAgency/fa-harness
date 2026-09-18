---
symptom: "A Shopify checkout/POS UI extension works when built for one environment (e.g. dev) but silently loses a config value (e.g. a backend base URL) at runtime in another (e.g. staging/production) — typically an 'Invalid base URL' error or a fetch failing against null/undefined, even though the build log shows the correct value being baked in."
root_cause: "Shopify CLI's esbuild step for extensions only substitutes specific process.env.<NAME> expressions with a literal value — it does not define a bare `process` global. A defensive guard like `typeof process !== 'undefined' && process.env.MY_VAR || null`, written to avoid a ReferenceError if the var is ever unset, survives into the bundle unchanged. In the extension's actual runtime sandbox there is no `process` global at all, so `typeof process !== 'undefined'` evaluates false and short-circuits the whole expression to null — even though the env-var reference itself was correctly inlined. Confirming the URL string appears somewhere in the built bundle is not sufficient; the guard expression itself must be evaluated with no `process` in scope to catch this."
fix: "Don't wrap an esbuild-inlined env var in a runtime typeof process guard inside extension code. Generate a small module containing only the literal value (no runtime reference to process at all) as a build step before the CLI bundles, and import that instead. A missing/ungenerated file then becomes a hard build-time resolve error instead of a silent runtime null."
affected_areas: ["checkout-ui-extensions build config", "esbuild env inlining"]
tags: [checkout-extension, esbuild, env-vars, process, build-time-config, sandbox]
date: 2026-09-01
author: ginthozan
clients_generalized_from: ["connox"]
severity: high
---

## Symptom / root cause
See frontmatter — the short version: `typeof process` is the bug, not the safety net
it looks like, because the extension sandbox has no `process` global to check.

## Fix
```js
// scripts/generate-app-url.mjs — run before `shopify app build` / `deploy`
import { writeFileSync } from "node:fs";
const url = /* resolve from the deploy target's own config, never a hardcoded literal */;
writeFileSync(
  "extensions/shared/appUrl.generated.js",
  `export const APP_URL = ${JSON.stringify(url)};\n`
);
// delete this generated file again once the CLI build/deploy step completes
```
```js
// extensions/shared/appUrl.js
export { APP_URL } from "./appUrl.generated.js"; // hard resolve error if missing, never a silent null
```

## How to verify
Load the actual built bundle in a sandboxed JS context (e.g. Node's `vm` module) with
no `process` global defined, and confirm it evaluates without error and produces the
expected literal. A build log showing the string present in the bundle text is not
enough — the expression *around* it has to be evaluated under sandbox conditions,
which is what actually catches this bug.

## Where else this applies
Any Shopify checkout UI extension, POS UI extension, or other CLI-bundled extension
that needs an environment-specific value (API base URL, feature flag, deploy target
id) baked in at build time via `shopify.app.<config>.toml` / esbuild `define`.
