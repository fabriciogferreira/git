# Mutation ledger (use-url-query project)

Personal stack for `~/git/use-url-query/prompts/mutation-testing.md`.

Mutation is mandatory after coverage; skip **only** when the user says `skip mutation`. Prefix rows with clone (`lib:` / `api:`). Lib uses Stryker (`bun run test:mutate` / scoped `--mutate`).

Feature: Spatie selecting fields — `addField` / `removeField` (lib + demo-api + demo-web).

| Clone | Scope | Status | Note | sha |
| --- | --- | --- | --- | --- |
| lib | `src/fields.ts` + `tests/field.test.tsx` | done | Stryker 100% (82 killed, 0 survived); `npx stryker run --mutate src/fields.ts` (`uq-mut-fields`, image with procps) | sha:065034e46826 |
| lib | `src/use-url-query.ts` (fields wiring) + `tests/field.test.tsx` | done | Stryker 100% (1 killed); scoped `--mutate` lines 96–110 / 317–319 / 341 / 389 (logic in `fields.ts`) | sha:4260bc6f9289 |
| api | `App\Services\User\UserService` | done | 0 mutants with `--covered-only` / `--class` (`allowedFields`); `--ignore-min-score-on-zero-mutations` | sha:8de566d75de0 |
| api | `App\Http\Requests\User\UserIndexRequest` | equivalent | 11/16 killed; 5× `RemoveArrayItem(sometimes)` equivalent (missing/empty/`null` same w/ without `sometimes` under Laravel validator) for filter/sort/fields | sha:27023124a746 |
