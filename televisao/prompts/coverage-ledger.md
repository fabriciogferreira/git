# Coverage ledger

Personal stack for `~/git/televisao/prompts/coverage-testing.md`. One row per production file under `~/git/televisao/televisao-api/app` after **in-scope (diff) coverage** plus the progressive **file ratchet** on this VM. Not part of the Televisão test suite / CI.

Gates (see the prompt): always cover the change-set hunks; **new/small** files (≤80 executable lines) go to File raw `100%`; **large** files must raise File raw by **+1 percentage point** vs the previous row (capped at 100%).

While any changed `app/**/*.php` from the card’s `televisao-api` diff is missing here or fails those gates, the coverage stack still has work: use **`next coverage`** (one file) or **`correct coverages`** (drain all remaining); do not run `pre-qa.md` via `next prompt` on own-card while files remain. On colleague dispatcher, drain remaining files in that run.

| File | Last measured | In-scope | Uncovered (in-scope) | File raw | Via test | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| `app/Broadcasting/Payloads/PrescriptionSignatureChangedPayload.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `100.0%` | `tests/Unit/Events/PrescriptionSignatureChangedTest.php` | `App\Broadcasting\Payloads\PrescriptionSignatureChangedPayload`; new file; File raw 100% |
| `app/Enums/SignatureStatusEnum.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `100.0%` | `tests/Unit/Events/PrescriptionSignatureChangedTest.php` | `App\Enums\SignatureStatusEnum`; hunk `isTerminal()`; small-file 100% |
| `app/Enums/WebSocketEventType.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `100.0%` | `tests/Unit/Events/PrescriptionSignatureChangedTest.php` | `App\Enums\WebSocketEventType`; hunk `PrescriptionSignatureChanged` case; small-file 100% |
| `app/Events/PrescriptionSignatureChanged.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `100.0%` | `tests/Unit/Events/PrescriptionSignatureChangedTest.php` | `App\Events\PrescriptionSignatureChanged`; new file; File raw 100% |
| `app/Models/PrescriptionSignature.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `100.0%` | `tests/Feature/Prescription/PrescriptionSignatureRealtimeTest.php`, `tests/Unit/Services/PrescriptionSignatureWebSocketRecipientResolverTest.php` | `App\Models\PrescriptionSignature`; hunk PHPDoc `|null` only — no executable in-scope lines; File raw 100% |
| `app/Services/AutentiqueWebhookService.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `89.8%` | `tests/Feature/Prescription/PrescriptionSignatureRealtimeTest.php`, `tests/Feature/Prescription/AutentiqueWebhookTest.php` | `App\Services\AutentiqueWebhookService`; large; first ledger row (baseline raw 89.8%); closed L231-233 / L382-385 via race+recover tests; PCOV in sandbox |
| `app/Services/PrescriptionSignatureWebSocketRecipientResolver.php` | `2026-11-17 11:01 -03` | `100%` | `—` | `100.0%` | `tests/Unit/Services/PrescriptionSignatureWebSocketRecipientResolverTest.php` | `App\Services\PrescriptionSignatureWebSocketRecipientResolver`; new file; File raw 100% |
