# Implementation (fabriciogferreira)

Implement `{{ feature }}`.

No cards, no PRs. Work on `main`. Shared rules: `~/git/fabriciogferreira/prompts/workflow-policy.md`.

If Docker or npm fails unexpectedly: stop, report, wait for `resolva` / `documente` / `resolva permanentemente`.

## 1. Context

1. Treat `{{ feature }}` as the source of truth.
2. Inspect `~/git/fabriciogferreira/fabriciogferreira` (`app/`, `components/`, `messages/` for i18n).
3. Prefer the smallest change. Do not expand scope.

## 2. Git

1. `git status` / `git diff`. Preserve unrelated local work.
2. Stay on `main`. `git pull --ff-only` when safe.
3. No feature branches, no PRs.

## 3. Plan then implement

1. Short plan: files, behavior, how to verify in the browser.
2. Implement. Keep next-intl / Tailwind patterns already in the repo.
3. Dev server: Docker `frontend` (`npm run dev`) or host-card front URL.
4. Smoke the changed route(s) locally.

## 4. Hand off

Recommend `~/git/fabriciogferreira/prompts/pre-deploy.md` (lint + build, then ship).

Do **not** commit or push unless the user asks or runs `pre-deploy`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run the next recommended prompt. |
| `try again` | Resume from the blocked step. |
