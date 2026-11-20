# Pre-deploy (boilerplate-laravel)

Ship `{{ feature }}` to production by committing and pushing `main`.

There is **no PR**. Push to `main` triggers deploy (`boilerplate-laravel` `.github/workflows/deploy.yml`). Shared rules: `~/git/boilerplate-laravel/prompts/workflow-policy.md`.

Commit and push **only** when this checklist’s applicable checks are green (or the user explicitly overrides). If a check fails: stop, fix or report, do not push.

## 1. Scope

1. List dirty files in `~/git/boilerplate-laravel/boilerplate-laravel`.
2. Confirm the diff matches `{{ feature }}` — no unrelated drive-by changes.
3. If `app/` changed and coverage/mutation ledgers still have remaining rows for this change-set, **stop** and drain `coverage-testing.md` / `mutation-testing.md` first.

## 2. Gates (`boilerplate-laravel`)

Run inside the Docker `workspace` service (from `COMPOSE_DIR` / compose.dev or the host-card project):

```bash
docker compose exec workspace php artisan test --compact
docker compose exec workspace vendor/bin/phpstan analyse --memory-limit=1G
docker compose exec workspace vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.dist.php --diff --ansi
```

(or `docker container exec …` on the running `workspace` container for this VM)

- [ ] Tests green (full suite, or the user-agreed affected set if they explicitly narrowed it).
- [ ] PHPStan clean.
- [ ] PHP CS Fixer applied; if it rewrote files, include those in the commit (do not leave a dirty formatter diff).
- [ ] If front assets changed: run the package lint/build the repo documents (`package.json` / Vite).

Investigate failures; do not assume they are unrelated.

## 3. Commit and push

**Proceed only after applicable gates pass.**

1. Stage only files for `{{ feature }}`.
2. Commit with a concise message focused on **why** (user must have asked to ship / run this prompt — this prompt is that ask).
3. `git push` to `main` on each affected repo (`-u` only if needed).
4. Report the commit SHA(s) and that deploy was triggered.

Do **not** open a pull request. Do **not** `--force` to `main`.

## 4. Hand off

Recommend `~/git/boilerplate-laravel/prompts/production-review.md` for `{{ feature }}` after the deploy has had time to finish.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `production-review.md`. |
| `try again` | Re-run the failed gate, then continue. |
