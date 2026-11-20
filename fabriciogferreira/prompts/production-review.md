# Production review (fabriciogferreira)

Verify `{{ feature }}` on **https://fabriciogferreira.vercel.app/** (or the live host the user names).

No cards. Shared rules: `~/git/fabriciogferreira/prompts/workflow-policy.md`.

## Before testing

1. Confirm `main` was pushed and the Vercel deploy finished.
2. Identify the acceptance path for `{{ feature }}` (locale, route, section).

## Verify

1. Exercise the primary path in production.
2. Check a relevant edge (e.g. other locale) when specified.
3. Short evidence: URL, action, expected, observed.

## Result

- **Pass:** Evidence per acceptance point.
- **Fail:** Steps + expected vs actual → recommend `correction.md`. Do not fix here.
- **Blocked:** Deploy still rolling / access missing. Do not claim Pass.

### Chat commands

| Command | Do this |
| --- | --- |
| `to correct` | After **Fail**, run `correction.md`. |
| `try again` | Re-check after a new deploy. |
