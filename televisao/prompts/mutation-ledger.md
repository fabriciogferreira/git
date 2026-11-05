# Mutation ledger

Personal stack for `~/git/televisao/prompts/mutation-testing.md`. One row per test file in `~/git/televisao/televisao-api/tests` after that file has been mutation-tested on this VM. Not part of the Televisão test suite.

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/Service/Consultation/ConsultationServiceMeetingTokenTest.php` | `100%` | `--class` `ConsultationService` + `ConsultationResource`; in-scope only (Service: no mutations on hunks 32/270-271/332; Resource 78–81 tested). Pest raw Resource 50% (legacy whenLoaded). +1 legacy: Resource L76 `RemoveArrayItem` `ad6ea79b1e12e2ac` via `id` key assert. |
| `tests/Feature/Prescription/PrescriptionStoreTest.php` | `100%` | `--class` `App\Policies\PrescriptionPolicy`; in-scope L28–30 (`isConsultationDoctor`) + L35 `create`. Killed `BooleanAndToBooleanOr` e8ed23b5587cdc56 with collaborator+doctor-profile-without-role case (local test only). Pest raw 100%. No +1 legacy. |
| `tests/Feature/Prescription/AutentiqueWebhookTest.php` | `100%` | `--class` `AutentiqueWebhookService` + `PrescriptionSignature`; in-scope only (Service L206/L278 `signed_document_url` RemoveArrayItem tested; fillable/phpdoc hunks no mutations). Pest raw Service 37.5% / Model 57.1% (legacy casts/metadata). +1 legacy: Model L79 provider cast `8cc52b7e68ff6d1d` via `toBeInstanceOf(SignatureProviderEnum)`. Local assertion only. |
| `tests/Feature/Prescription/PrescriptionSignatureCurrentTest.php` | `100%` | `--class` `PrescriptionSignature` + `PrescriptionService` + `AutentiqueWebhookService`; in-scope only (Model fillable/phpdoc hunks no mutations; Service preview L127 not covered by this GET; Webhook 0 mutations). Pest raw Model 42.9% (legacy casts) / Service `currentSignature` L319–325 100% out-of-scope / Webhook n/a. +1 legacy: Model L78 status cast `aa957dc6edec4450` via `toBeInstanceOf(SignatureStatusEnum)`. Local assertion only. |
