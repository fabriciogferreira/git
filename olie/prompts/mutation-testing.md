# Mutation testing (personal)

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/olie/prompts/workflow-policy.md`.

Personal workflow on this VM. Pest mutation testing is not an Olie team practice. Do not add it to `api-main` CI, `phpunit.xml`, Dockerfiles, `docker-workspace`, or Composer. Do not commit `covers()` or `mutates()` into company tests. Do not open a pull request whose purpose is mutation testing. Assertion edits that make a mutation fail are normal test changes in `~/git/olie/api-main`; do not commit or push them unless the user asks in this chat.

## Ledger

Progress lives only in `~/git/olie/prompts/mutation-ledger.md` (meta-repo). Create that file if it is missing, with a table:

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/...` | `100%` or `equivalent` | short note |

A row is done when Result is `100%` or `equivalent`. `equivalent` means every remaining untested mutation is a behavior-preserving change (for example a cast the tests already feed as a float) and the Notes column says why. Do not mark a file done to skip a real gap.

## One file per paste

1. List every `*Test.php` under `~/git/olie/api-main/tests`. Sort by path.
2. Skip paths already done in the ledger.
3. Take the first remaining path. If the user named a test file in the same message, use that path instead, even if it is not next.
4. If none remain, say the stack is complete and stop.
5. Prepare, run, and record that one file. Stop. Do not start the next file in this paste. The stack grows by pasting this prompt again.

## Prepare

All PHP runs as `docker exec -w /var/www/html olie-api-main <command>`. Do not run `php` on the host.

- If `vendor/bin/pest-plugins.json` is missing inside the container: `composer pest:dump-plugins`.
- If `php -m` does not list `pcov`: install it in the running container only (`pecl install pcov` and `docker-php-ext-enable pcov` as root). Say that a recreated image drops PCOV. Do not change the image or compose files.

Run the chosen file with the normal suite first:

`docker exec -w /var/www/html olie-api-main php artisan test --compact <test-path>`

If that fails, stop. Do not mutate a red file.

## Mutate

`docker exec -w /var/www/html olie-api-main vendor/bin/pest --mutate --covered-only --min=100 --ignore-min-score-on-zero-mutations <test-path>`

`--covered-only` mutates lines this file already executes. No `covers()` call is required. `--ignore-min-score-on-zero-mutations` treats a file with nothing to mutate as success.

## Close the file

- Score 100%, or zero mutations: append a `100%` row (notes: `no mutations` when zero). Stop.
- Untested mutations: tighten assertions in that test file so the mutated behavior fails the test. Re-run the same mutate command. Do not change production code to satisfy a mutation. If a mutation shows a real product bug, stop and report it.
- Untested mutation that does not change behavior: record `equivalent` and name the mutation id and why. Do not invent an assertion that cannot fail.

After the row is written, report the file, the score, and how many test files are still absent from the ledger.
