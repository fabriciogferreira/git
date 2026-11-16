# Coverage ledger

Personal stack for `~/git/locav/prompts/coverage-testing.md`. One row per production file under `~/git/locav/LocavApi/app` after **in-scope (diff) coverage** plus the progressive **file ratchet** on this VM. Not part of the Locav test suite / CI.

Gates (see the prompt): always cover the change-set hunks; **new/small** files (≤80 executable lines) go to File raw `100%`; **large** files must raise File raw by **+1 percentage point** vs the previous row (capped at 100%).

While any changed `app/**/*.php` from the card’s `LocavApi` diff is missing here or fails those gates, the coverage stack still has work: use **`next coverage`** (one file) or **`correct coverages`** (drain all remaining); do not run `pre-qa.md` via `next prompt` on own-card while files remain. On colleague QA/CR, finish coverage before approve/merge / 'Revisado'.

| File | Last measured | In-scope | Uncovered (in-scope) | File raw | Via test | Notes |
| --- | --- | --- | --- | --- | --- | --- |
