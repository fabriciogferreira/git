# Mutation ledger

Personal stack for `~/git/olie/prompts/mutation-testing.md`. One row per test file in `~/git/olie/api-main/tests` after that file has been mutation-tested on this VM. Not part of the Olie test suite.

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/Feature/Automation/ProjectContentAddActionAttachmentsTest.php` | `100%` / `equivalent` | CreateMediaFromFrameAttachment `100%`. ProjectContentAddAction in-scope `equivalent` (Pest raw 92%): `5e6a812a` (destination `channel_id` fallback unused — text media always has channel_id), `d3e85ce4` (`(string)` cast; model_type already string), `7db7fb25` (`loadMissing` — Eloquent lazy-loads). ComponentValidator: 0 mutations under this file. |
| `tests/Feature/Automation/Validations/ProjectContentAddConfigValidationTest.php` | `equivalent` | in-scope ComponentValidator L669–725; Pest raw ~35% (fat class). equivalent: `a7fa3097` (remove `string`; `Rule::in` still rejects), `32e38dba` (`$fail(__('validation.exists',[]))` — Validator re-injects `:attribute`). +1 legacy: `1ae14b74` close_reason must be string |
| `tests/Feature/Octane/FlushOctaneStateTest.php` | `100%` | FlushOctaneState `100%` (7/7; in-scope L46 flush TemplateEngineDataCache). TemplateEngineDataCache `100%` (2/2; whole new file). CacheableDataProvider + TemplateService: `no mutations` under this file. in-scope only. |
| `tests/Feature/Spreadsheet/ProjectExecution/ProjectExecutionSpreadsheetExportRouteTest.php` | `100%` | `--class` ProjectExecutionSpreadsheetColumnSet: `no mutations` (enum; Pest 0 files even without `--covered-only`). ProjectExecutionExportValidator: in-scope = comments + deleted `seeTimers` only → `no mutations`; Pest raw 0% on 23 out-of-scope `rules()` mutations (pre-existing). Temporary `mutates()` removed. No +1 legacy. |
