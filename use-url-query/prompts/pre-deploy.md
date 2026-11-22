# Pre-deploy (use-url-query)

Ship `{{ feature }}` by committing and pushing `main`.

There is **no PR**. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Commit and push **only** when this checklist’s applicable checks are green (or the user explicitly overrides). If a check fails: stop, fix or report, do not push.

Publish to npm **only** when the user explicitly asks (not implied by this prompt alone).

## 1. Scope

1. List dirty files in `~/git/use-url-query/use-url-query`.
2. Confirm the diff matches `{{ feature }}` — no unrelated drive-by changes.
3. If `src/` changed and coverage ledger still has remaining rows for this change-set, **stop** and drain `coverage-testing.md` first.
4. If `src/` changed and mutation is not done for this change-set and the user has **not** said `skip mutation`, **stop** and run `mutation-testing.md` first (Blocked until tool or explicit skip is fine — do not push).

## 2. Gates (`use-url-query`)

Ship gate (re-validate after coverage/mutation). Run inside the Docker `use-url-query` service (from `COMPOSE_DIR` / host-card):

```bash
docker compose exec use-url-query bun test
docker compose exec use-url-query bun run build
```

- [ ] Tests green (full suite, or the user-agreed affected set if they explicitly narrowed it).
- [ ] `tsc` build (`bun run build`) clean; `dist/` artifacts match package exports if they are committed (follow repo convention — do not force-commit `dist/` if `.gitignore` excludes it).

Investigate failures; do not assume they are unrelated.

## 3. Commit and push

**Proceed only after applicable gates pass.**

1. Stage only files for `{{ feature }}`.
2. Commit with a concise message focused on **why** (user must have asked to ship / run this prompt — this prompt is that ask).
3. `git push` to `main` (`-u` only if needed).
4. Report the commit SHA. If the user also asked to publish: bump version per their instruction, `bun publish` / `npm publish`, report the version.

Do **not** open a pull request. Do **not** `--force` to `main`.

## 4. Hand off

Recommend `~/git/use-url-query/prompts/production-review.md` for `{{ feature }}`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `production-review.md`. |
| `try again` | Re-run the failed gate, then continue. |
