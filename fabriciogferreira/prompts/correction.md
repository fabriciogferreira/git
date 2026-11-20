# Correction (fabriciogferreira)

Fix production (or pre-deploy) findings for `{{ feature }}`.

No cards, no PRs. Work on `main`. Shared rules: `~/git/fabriciogferreira/prompts/workflow-policy.md`.

## 1. Context

1. Use `{{ feature }}` plus the Fail report from `production-review.md` (or a failed gate).
2. Prefer root causes over symptoms.

## 2. Git

Stay on `main`. `git pull --ff-only` when safe. No PRs.

## 3. Fix

1. Confirm each finding when possible.
2. Minimal fix; re-check the affected route(s).
3. Re-run `npm run lint` on the changed area when relevant.

## 4. Hand off

Recommend `~/git/fabriciogferreira/prompts/pre-deploy.md`, then `production-review.md` after deploy.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `pre-deploy.md`. |
| `try again` | Resume correction from the blocked finding. |
