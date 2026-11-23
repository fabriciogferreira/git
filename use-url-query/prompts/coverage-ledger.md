# Coverage ledger (use-url-query project)

Personal stack for `~/git/use-url-query/prompts/coverage-testing.md`. One row per production file (prefix clone: `lib:` / `api:` / `web:` if needed) after in-scope coverage on this VM.

Feature: Spatie selecting fields — `addField` / `removeField` (lib + demo-api + demo-web).

| Clone | File | Status | Note | sha |
| --- | --- | --- | --- | --- |
| lib | `src/fields.ts` | done | 100% lines/stmts/branches/funcs (`uq-cov-fields`) | sha:065034e46826 |
| lib | `src/use-url-query.ts` | done | in-scope fields hunks covered; uncovered L125=`removeFilter` (out of scope) | sha:4260bc6f9289 |
| lib | `src/index.ts` | n/a | `vitest.config.ts` coverage.exclude | |
| api | `app/Services/User/UserService.php` | done | clover 8/8 stmts (`UserIndexTest`) | sha:8de566d75de0 |
| api | `app/Http/Requests/User/UserIndexRequest.php` | done | clover 7/7 stmts (`UserIndexTest`) | sha:27023124a746 |
