# Coverage ledger (Opbed)

Personal stack for `~/git/opbed/prompts/coverage-testing.md`. One row per production file under `opbed-backend/app` after in-scope coverage on this VM.

Feature: addiction progress on /job  
sha:86a27c243f14

| File | Last measured | In-scope | Uncovered (in-scope) | File raw | Via test | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `app/Http/Requests/User/UserUpdateRequest.php` | 2026-11-23 | lines 208–213 (`addiction_progress_days` rules) | none | 0.0% (whole Form Request; PCOV) | `tests/Feature/User/UserUpdateTest.php` (15 addiction cases) | In-scope rules exercised by HTTP 422/200. All `Http/Requests/**` report 0% under PCOV here (class loaded before coverage start). |
