# Production review (use-url-query)

Verify `{{ feature }}` on the **shipped** artifact (npm package and/or `main` tip consumers care about). Local success is not enough.

No cards, no board moves. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

If tooling fails unexpectedly: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## Before testing

1. Confirm the change for `{{ feature }}` was pushed to `main` (and published to npm if that was part of the ship).
2. Identify how consumers get the package (`@fabriciogferreira/use-url-query` on npm, or git dependency).
3. Identify the acceptance path implied by `{{ feature }}` (API surface, types, URL/query behavior).

## Verify

1. Confirm the expected version/commit is what consumers resolve (npm view / lockfile / git SHA).
2. Spot-check the public API for `{{ feature }}` (types in `dist` or README examples) against the intended behavior.
3. Record short evidence: version/SHA, check performed, expected, observed.

## Result

Report the verdict first.

- **Pass:** Each acceptance point with evidence. Recommend stopping or the next feature.
- **Fail:** Failed point, reproducible steps, expected vs actual. Do **not** fix in this prompt. Recommend `~/git/use-url-query/prompts/correction.md` with the same `{{ feature }}`.
- **Blocked:** Missing publish access, package not yet visible, or unclear consumer path. Do not claim Pass.

### Chat commands

| Command | Do this |
| --- | --- |
| `to correct` | After **Fail**, run `correction.md` for `{{ feature }}`. |
| `try again` | Re-check after a new publish or cleared block. |
