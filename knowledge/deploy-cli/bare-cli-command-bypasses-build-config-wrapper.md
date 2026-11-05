---
symptom: "`shopify app deploy` / `shopify app build` fails at the bundling step with an esbuild error like `Could not resolve \"./<something>.generated.js\"`, pointing at a shared module the repo genuinely does not contain. Nothing is broken in the working tree and the file is correctly gitignored."
root_cause: "The repo generates that module from the deploy target's own config immediately before the CLI bundles, via a wrapper script invoked by an npm script, and deletes it again on exit. Running the Shopify CLI directly skips the wrapper, so the module is absent and the import cannot resolve. This is the generated-module pattern working as designed, but the error names a missing file rather than the missing wrapper, so it reads as a broken checkout — especially to anyone with `shopify app deploy` in muscle memory, in a README, or in a CI job written before the wrapper existed."
fix: "Invoke the wrapped npm script (`npm run deploy:<target>`), never the bare CLI command. Make the failure self-describing: a header comment in the consuming module explaining that its absence means the wrapper was skipped, and npm `deploy`/`build` scripts with no default target that exit non-zero telling the caller which target-specific script to run."
affected_areas: ["extension build wrapper scripts", "npm run-scripts", "shopify app deploy", "esbuild module resolution"]
tags: [deploy-cli, build-time-config, generated-module, wrapper-script, esbuild, non-interactive, ci]
date: 2026-11-05
author: ginthozan
clients_generalized_from: ["connox"]
severity: medium
---

## Symptom

The extension bundling step fails outright:

```
✘ [ERROR] Could not resolve "./appUrl.generated.js"
    extensions/shared/appUrl.js:24:22
```

The named file is absent from the repo and listed in `.gitignore`, so the first
instinct is that someone forgot to commit it. Committing it is exactly the wrong
move — see below.

## Root cause

This is the follow-on trap from
[esbuild-typeof-process-guard-nulls-inlined-url](../checkout-extensions/esbuild-typeof-process-guard-nulls-inlined-url.md).
Once an environment-specific value is supplied as a *generated module* instead of an
inlined env var, the build acquires a mandatory pre-step. A wrapper script reads the
value out of the config the command is targeting, writes the module, runs the CLI,
and deletes the module on exit. The deletion is deliberate: a leftover file would let
a later bare command bundle a stale value from a previous target.

So the raw CLI command stops being a valid entry point. It does not degrade — it
hard-fails, which is the intended trade (a loud build error over a silent wrong-origin
bundle). But esbuild reports the *symptom* (unresolved import), not the *cause*
(wrapper skipped), and the two look nothing alike.

## Fix

Run the wrapped script. Then make the next person's failure self-explaining.

Put the explanation where the error points — the consuming module, since that file
path is what esbuild prints:

```js
// extensions/shared/<value>.js
//
// The value is not written here. <wrapper script> derives it from the config named by
// the command's own --config flag, writes ./<value>.generated.js just before the CLI
// bundles, and deletes it on exit.
//
// Always go through the npm scripts. A bare CLI command skips the wrapper, leaving
// this import unresolved — that hard failure is deliberate; see <link to the entry
// explaining why a generated module replaced an inlined env var>.
export { VALUE } from './<value>.generated.js';
```

And remove the un-targeted script name as a thing anyone can successfully run, so the
habit fails fast and says what to do instead:

```jsonc
{
  "deploy":            "echo 'Pick a target: npm run deploy:dev or npm run deploy:production' && exit 1",
  "deploy:dev":        "node scripts/<wrapper>.mjs shopify app deploy --config dev",
  "deploy:production": "node scripts/<wrapper>.mjs shopify app deploy --config production"
}
```

Take the target from the forwarded command's own `--config` flag rather than passing
it to the wrapper separately — one place names the target, so the generated value and
the app being deployed cannot drift apart.

## Running it non-interactively

A wrapped deploy still prompts for confirmation, which hangs any non-TTY caller
(CI, an agent, a background job). On current CLI versions the flag for this is
**not** `--force` — that was removed and now errors with `Nonexistent flag: --force`:

- `--allow-updates` — adds and updates extensions without confirmation. The right
  default: it still aborts if the deploy would *remove* an extension.
- `--allow-deletes` — also permits removals. Only when a removal is intended.
- `--message "..."` — labels the released version; worth setting so the Partner
  dashboard version list is readable afterwards.

Extra flags pass through an npm script with `--`:
`npm run deploy:production -- --allow-updates --message "..."`.

## Where else this applies

Any repo where a build needs a value that varies by deploy target and must end up as
a literal in the bundle — API base URLs, feature flags, target ids — and has solved
it with a generate-before-build wrapper. The same shape shows up outside Shopify
wherever a gitignored generated module sits between the source and the bundler. Two
checks whenever that pattern is introduced:

1. Grep the repo and CI config for the bare command the wrapper replaced. A workflow
   file still calling it will fail on the next run, far from whoever made the change.
2. Never "fix" the error by committing the generated file. That restores the exact
   silent-wrong-value failure the generated module was introduced to eliminate, and
   it will bundle whichever target happened to be generated last.
