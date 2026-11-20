# Pre-deploy (Opbed)

Ship `{{ feature }}` to production by committing and pushing `main`.

There is **no PR**. Push to `main` triggers deploy (`opbed-backend` `.github/workflows/deploy.yml` → Coolify). Shared rules: `~/git/opbed/prompts/workflow-policy.md`.

Commit and push **only** when this checklist’s applicable checks are green (or the user explicitly overrides). If a check fails: stop, fix or report, do not push.

## 1. Scope

1. List dirty files in `opbed-backend` and/or `opbed-frontend`.
2. Confirm the diff matches `{{ feature }}` — no unrelated drive-by changes.
3. If backend `app/` changed and coverage/mutation ledgers still have remaining rows for this change-set, **stop** and drain `coverage-testing.md` / `mutation-testing.md` first.

## 2. Backend gates (`opbed-backend`)

Run inside the Docker `backend` service (project Environment rule):

```bash
docker compose exec backend php artisan test --compact
docker compose exec backend vendor/bin/phpstan analyse --memory-limit=1G
docker compose exec backend vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.dist.php --diff --ansi
```

(or `docker container exec …` on the running backend container name for this VM)

- [ ] Tests green (full suite, or the user-agreed affected set if they explicitly narrowed it).
- [ ] PHPStan clean.
- [ ] PHP CS Fixer applied; if it rewrote files, include those in the commit (do not leave a dirty formatter diff).

Investigate failures; do not assume they are unrelated.

## 3. Frontend gates (`opbed-frontend`, if changed)

- [ ] Run the repo’s lint / typecheck / test commands from that clone’s docs or `package.json`.
- [ ] Fix issues introduced by this change.

## 4. Commit and push

**Proceed only after applicable gates pass.**

1. Stage only files for `{{ feature }}`.
2. Commit with a concise message focused on **why** (user must have asked to ship / run this prompt — this prompt is that ask).
3. `git push` to `main` on each affected repo (`-u` only if needed).
4. Report the commit SHA(s) and that deploy was triggered.

Do **not** open a pull request. Do **not** `--force` to `main`.

## 5. Hand off

Recommend `~/git/opbed/prompts/production-review.md` for `{{ feature }}` after the deploy has had time to finish.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `production-review.md`. |
| `try again` | Re-run the failed gate, then continue. |
