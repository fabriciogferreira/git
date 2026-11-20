# Coverage testing (fabriciogferreira)

This portfolio has **no unit-test suite** by default (`package.json` only has `dev` / `build` / `lint` / `start`).

When the user asks for coverage:

1. Prefer adding focused tests only if they explicitly want a test runner introduced.
2. Otherwise treat this as a **skip**: recommend `mutation-testing.md` (also skip) then `pre-deploy.md`.
3. For quality gates use `npm run lint` + `npm run build` in sandbox if parallel jobs are needed:

```bash
~/git/bin/workvm-sandbox create --name <id> --project fabriciogferreira --profile tests --from-commit <tip>
~/git/bin/workvm-sandbox job run <id> --service backend -- npm run lint
```

Ledger: `coverage-ledger.md` may stay empty or note `n/a | skipped | no test suite`.
