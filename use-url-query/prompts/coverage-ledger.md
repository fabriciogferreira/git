# Coverage ledger (use-url-query project)

Personal stack for `~/git/use-url-query/prompts/coverage-testing.md`. One row per production file (prefix clone: `lib:` / `api:` / `web:` if needed) after in-scope coverage on this VM.

Feature: Spatie `sort` / `cycleSort` for `name` (lib + demo-api + demo-web).

| Clone | File | Status | Note | sha |
| --- | --- | --- | --- | --- |
| lib | `src/sorts.ts` | done | 100% lines/stmts/branches (`uq-cov-sort` + Node image) | sha:1e334acb1db1+2543bce76144 |
| lib | `src/use-url-query.ts` | done | 100% lines; unknown-column guards covered | sha:a3d7b4e0fa65+04c2931511c2 |
| lib | `src/index.ts` | n/a | `vitest.config.ts` coverage.exclude | |
| api | `app/Services/User/UserService.php` | done | clover 7/7 stmts (`UserIndexTest`) | sha:8346867db37b+94bed46533a0 |
| api | `app/Http/Requests/User/UserIndexRequest.php` | done | clover 5/5 stmts (`UserIndexTest`) | sha:d8f3b28d265e+94bed46533a0 |
