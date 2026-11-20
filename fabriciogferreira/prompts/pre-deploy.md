# Pre-deploy (fabriciogferreira)

Ship `{{ feature }}` by committing and pushing `main` (Vercel deploy).

There is **no PR**. Shared rules: `~/git/fabriciogferreira/prompts/workflow-policy.md`.

Commit and push **only** when gates are green (or the user overrides).

## 1. Scope

1. Dirty files in `~/git/fabriciogferreira/fabriciogferreira` match `{{ feature }}`.
2. No unrelated drive-by changes.

## 2. Gates

Inside the Docker `frontend` / sandbox `backend` / host-card frontend:

```bash
npm run lint
npm run build
```

- [ ] Lint clean.
- [ ] Production build succeeds.

## 3. Commit and push

1. Stage only files for `{{ feature }}`.
2. Concise commit focused on **why**.
3. `git push` to `main` (no `--force`).
4. Report the SHA and that Vercel should deploy.

## 4. Hand off

Recommend `~/git/fabriciogferreira/prompts/production-review.md`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `production-review.md`. |
| `try again` | Re-run the failed gate, then continue. |
