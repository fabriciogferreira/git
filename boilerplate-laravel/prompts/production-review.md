# Production review (boilerplate-laravel)

Verify `{{ feature }}` on **production**. Local success is not enough.

No cards, no board moves. Shared rules: `~/git/boilerplate-laravel/prompts/workflow-policy.md`.

If tooling or browser automation fails unexpectedly: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`. A CAPTCHA / human login handoff is expected — ask the user; do not treat it as broken tooling.

## Before testing

1. Confirm the change for `{{ feature }}` was pushed to `main` and the deploy finished (`.github/workflows/deploy.yml`).
2. Open the live production host for this project (not `localhost`). Sign in with the credentials the user provides or already uses in this environment. Do not invent passwords or paste secrets into the report.
3. Identify the acceptance path and any error/edge path implied by `{{ feature }}`.

## Verify

1. Exercise the primary path for `{{ feature }}` in production.
2. Exercise a relevant error/edge path when safe and specified.
3. Record short evidence: URL/area, action, expected, observed (redact secrets).

## Result

Report the verdict first.

- **Pass:** Each acceptance point with production evidence. Recommend stopping or the next feature.
- **Fail:** Failed point, reproducible steps, expected vs actual. Do **not** fix in this prompt. Recommend `~/git/boilerplate-laravel/prompts/correction.md` with the same `{{ feature }}`.
- **Blocked:** Missing access, deploy still rolling, or data prerequisite. Do not claim Pass.

### Chat commands

| Command | Do this |
| --- | --- |
| `to correct` | After **Fail**, run `correction.md` for `{{ feature }}`. |
| `try again` | Re-check after a new deploy or cleared block. |
