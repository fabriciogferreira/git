# Pre-deploy (use-url-query project)

Ship `{{ feature }}` by committing and pushing `main` on **each dirty project clone**.

There is **no PR**. Shared rules: `~/git/use-url-query/prompts/workflow-policy.md`.

Commit and push **only** when this checklist’s applicable checks are green (or the user explicitly overrides). If a check fails: stop, fix or report, do not push.

Publish the library to npm **only** when the user explicitly asks (not implied by this prompt alone).

## 1. Scope

1. List dirty files in all three clones: lib, demo-api, demo-web.
2. Confirm each diff matches `{{ feature }}` — no unrelated drive-by changes. Skip clean clones.
3. If lib `src/` or demo-api production PHP changed and coverage ledger still has remaining rows for this change-set, **stop** and drain `coverage-testing.md` first.
4. If those areas changed and mutation is not done and the user has **not** said `skip mutation`, **stop** and run `mutation-testing.md` first.

## 2. Gates (only for dirty clones)

### Library (`use-url-query`)

Host-card `lib` / compose `use-url-query` service:

```bash
docker compose exec use-url-query bun test
docker compose exec use-url-query bun run build
```

- [ ] Tests green.
- [ ] `tsc` (`bun run build`) clean.

### Demo API (`use-url-query-demo-api`)

Host-card `workspace` (e.g. `hc-…-workspace-1`):

```bash
php artisan test --compact --ci
./vendor/bin/pest --type-coverage --min=100
vendor/bin/phpstan analyse --memory-limit=1G
vendor/bin/php-cs-fixer fix --config=.php-cs-fixer.dist.php --diff --ansi
```

- [ ] Tests green.
- [ ] Type Coverage 100%.
- [ ] PHPStan clean.
- [ ] CS Fixer applied; include formatter diffs in the commit.

### Demo web (`use-url-query-demo-web`)

- [ ] Run the clone’s lint / typecheck / test commands from its docs or `package.json`.
- [ ] Fix issues introduced by this change.

Investigate failures; do not assume they are unrelated.

## 3. Commit and push

**Proceed only after applicable gates pass.**

For **each** dirty clone:

1. Stage only files for `{{ feature }}`.
2. Commit with a concise message focused on **why**.
3. `git push` to `main` (`-u` only if needed).
4. Report the commit SHA.

If the user also asked to publish the library: bump version per their instruction, `bun publish` / `npm publish`, report the version.

Do **not** open a pull request. Do **not** `--force` to `main`.

## 4. Hand off

Recommend `~/git/use-url-query/prompts/production-review.md` for `{{ feature }}`.

### Chat commands

| Command | Do this |
| --- | --- |
| `next prompt` | Run `production-review.md`. |
| `try again` | Re-run the failed gate, then continue. |
