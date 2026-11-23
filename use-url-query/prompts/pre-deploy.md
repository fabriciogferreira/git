# Pre-deploy (use-url-query project)

Ship `{{ feature }}` by committing and pushing `main` on **each dirty project clone**.

There is **no PR**. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Commit and push **only** when this checklist’s applicable checks are green (or the user explicitly overrides). If a check fails: stop, fix or report, do not push.

Publish the library to npm when this ship **changes** `package.json` `version` in the lib clone (compare to `origin/main` before the commit). Unchanged version → do not publish. Do not bump the version unless the user already did.

## 1. Scope

1. List dirty files in all three clones: lib, demo-api, demo-web.
2. Confirm each diff matches `{{ feature }}` — no unrelated drive-by changes. Skip clean clones.
3. If lib `src/` or demo-api production PHP changed and coverage ledger still has remaining rows for this change-set, **stop** and drain `coverage-testing.md` first.
4. If those areas changed and mutation is not done and the user has **not** said `skip mutation`, **stop** and run `mutation-testing.md` first.

## 2. Gates (only for dirty clones)

When the agent Shell hides `docker.sock` (silent sandbox), use
`~/git/bin/workvm-host-card agent-docker --project use-url-query --code use-url-query --container <svc> -- …`
instead of `docker compose exec` / `docker exec`.

### Library (`use-url-query`)

Host-card `lib` (Bun+Node image):

```bash
# Prefer docker compose exec when sock is visible; else agent-docker:
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container lib -- bun run test
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container lib -- bun run build
```

- [ ] Tests green.
- [ ] `tsc` (`bun run build`) clean.

### Demo API (`use-url-query-demo-api`)

Host-card `workspace` (e.g. `hc-…-workspace-1`):

```bash
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container workspace -- php artisan test --compact --ci
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container workspace -- php -d memory_limit=2G ./vendor/bin/pest --type-coverage --min=100
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container workspace -- vendor/bin/phpstan analyse --memory-limit=1G
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container workspace -- vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.dist.php --diff --ansi
```

- [ ] Tests green.
- [ ] Type Coverage 100%.
- [ ] PHPStan clean.
- [ ] CS Fixer applied; include formatter diffs in the commit.

### Demo web (`use-url-query-demo-web`)

```bash
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container front -- npm run lint
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container front -- npm run typecheck
workvm-host-card agent-docker --project use-url-query --code use-url-query \
  --container front -- npm run test -- --run
```

- [ ] Lint clean.
- [ ] `npm run typecheck` clean (`next typegen` + `tsc --noEmit` — same TS gate as `next build`).
- [ ] Tests green.
- [ ] Fix issues introduced by this change.

Investigate failures; do not assume they are unrelated.

## 3. Commit and push

**Proceed only after applicable gates pass.**

For **each** dirty clone:

1. Stage only files for `{{ feature }}`.
2. Commit with a concise message focused on **why**.
3. `git push` to `main` (`-u` only if needed).
4. Report the commit SHA.

If the committed lib `package.json` `version` differs from the previous `origin/main` version, publish from the lib clone after the push (`prepublishOnly` already runs `bun run build`):

```bash
bun publish
```

Report the published version. If `src/` changed and `version` did not, say npm still has the previous version — do not publish and do not invent a bump.

Do **not** open a pull request. Do **not** `--force` to `main`.

## 4. Hand off

Recommend `~/git/use-url-query/prompts/production-review.md` for `{{ feature }}`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `production-review.md`. |
| `try again` | Re-run the failed gate, then continue. |
