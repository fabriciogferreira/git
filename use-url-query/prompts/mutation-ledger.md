# Mutation ledger (use-url-query project)

Personal stack for `~/git/use-url-query/prompts/mutation-testing.md`.

Mutation is mandatory after coverage; skip **only** when the user says `skip mutation`. Prefix rows with clone (`lib:` / `api:`). Lib uses Stryker (`bun run test:mutate` / scoped `--mutate`).

Feature: Spatie `sort` / `cycleSort` for `name`.

| Clone | Scope | Status | Note | sha |
| --- | --- | --- | --- | --- |
| lib | `src/sorts.ts` + `tests/sort.test.ts` | done | Stryker 100% (37 killed, 0 survived); `npx stryker run --mutate src/sorts.ts` | e69ae42 |
| lib | `src/use-url-query.ts` (cycleSort / sort sync) + `tests/use-url-query.test.tsx` | done | Stryker 100% (2 killed); scoped `--mutate src/use-url-query.ts:264-266` (full file ~234 mutants / hours — out of change-set; logic in `sorts.ts`) | e69ae42 |
| api | `App\Services\User\UserService` | done | 0 mutants with `--covered-only` / `--class` (`allowedSorts('name')`); `--ignore-min-score-on-zero-mutations` | sha:8346867db37b+94bed46533a0 |
| api | `App\Http\Requests\User\UserIndexRequest` | equivalent | 7/10 killed; 3× `RemoveArrayItem(sometimes)` equivalent (missing/empty/`null` same w/ without `sometimes` under Laravel validator); `sort` string covered by `rejects a non-string sort` | sha:d8f3b28d265e+94bed46533a0 |
