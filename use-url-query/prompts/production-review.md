# Production review (use-url-query project)

Verify `{{ feature }}` on what was **shipped** for this project. Local success is not enough.

No cards, no board moves. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Project-scoped: decide which shipped surfaces matter (lib package, demo-api, demo-web) from `{{ feature }}` and the pre-deploy SHAs.

If tooling fails unexpectedly: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## Before testing

1. Confirm each affected clone was pushed to `main`. If that ship changed the lib `package.json` `version`, confirm that version is on npm.
2. Identify consumer paths: npm/`@fabriciogferreira/use-url-query`, demo-web against demo-api, Spatie query-string behavior, etc.
3. Identify the acceptance path implied by `{{ feature }}`.

## Verify

1. Confirm expected version/commit(s) for each affected surface.
2. Spot-check behavior for `{{ feature }}` on those surfaces (public API, demo HTTP, URL/query contract).
3. Record short evidence: version/SHA, check performed, expected, observed.

## Result

Report the verdict first.

- **Pass:** Each acceptance point with evidence. Recommend stopping or the next feature.
- **Fail:** Failed point, reproducible steps, expected vs actual. Do **not** fix in this prompt. Recommend `~/git/use-url-query/prompts/correct.md` with the same `{{ feature }}`.
- **Blocked:** Missing publish/deploy access, package not yet visible, demos unreachable, or unclear consumer path. Do not claim Pass.

### Chat commands

| Command | Do this |
| --- | --- |
| `to correct` | After **Fail**, run `correct.md` for `{{ feature }}`. |
| `try again` | Re-check after a new publish/push or cleared block. |
