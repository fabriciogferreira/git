# Mutation ledger

Personal stack for `~/git/televisao/prompts/mutation-testing.md`. One row per test file in `~/git/televisao/televisao-api/tests` after that file has been mutation-tested on this VM. Not part of the Televisão test suite.

| Test file | Result | Notes |
| --- | --- | --- |
| `tests/Service/Consultation/ConsultationServiceMeetingTokenTest.php` | `100%` | `--class` `ConsultationService` + `ConsultationResource`; in-scope only (Service: no mutations on hunks 32/270-271/332; Resource 78–81 tested). Pest raw Resource 50% (legacy whenLoaded). +1 legacy: Resource L76 `RemoveArrayItem` `ad6ea79b1e12e2ac` via `id` key assert. |
