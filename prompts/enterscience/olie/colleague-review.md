# Colleague Card Review

Review card {{ code }} while it sits in 'QA/CR'. The workday order stays in `workflow.md`. This is not `pre-qa.md`. That file prepares your own card. This file reviews someone else's.

## 1. Objective

Decide whether the implementation does what the card requested. Report the result. Do not implement the card.

The card's requirements and acceptance criteria are the source of truth. A change that works but does not match the card is not a pass.

## 2. Context

Load the card through `mcp olie-flow-ai`. Read:

- The description, requirements, and acceptance criteria.
- The repositories and branches the author changed.
- The pull requests and the commits on those branches.
- Comments, attachments, and test notes.

Do not review from the card title alone.

## 3. What you may change

Do not edit product repositories. That includes `olie-fronts`, `api-main`, `backoffice`, `landing`, `docker-workspace`, and `websocket`.

You may change only `~/git/projects/olie/olie-e2e`. That tree is not part of the company remotes.

- If the author changed `olie-fronts`, add end-to-end tests there for the frontend behavior the card requested.
- If those tests already exist and a requested point is uncovered, add the missing tests.
- Do not rewrite tests that already cover the card.

For `~/git/`, do not create a card branch. Commit and push the e2e changes directly to 'main'.

Do not commit product code, secrets, or `.env` files. Do not open a pull request on a company repository.

## 4. Branches to test

On each company repository the card touches:

1. Find the branch the author created.
2. Check it out so you can run the feature.
3. If that branch does not exist yet, create it from the repository's base (`develop` or `master`, as that repository uses).
4. Do not rename their branch and do not commit on it.

Leave unrelated local changes untouched. If a checkout would overwrite them, stop and report the blocker.

## 5. What to verify

- The behavior matches the card, including the edge cases the card states.
- The pull request contains that behavior and does not smuggle unrelated changes.
- Light and dark theme text contrast both hold on the screens the card changes.
- Do not flag a missing key in 'en.json' when the new key exists in 'pt-br.json'. Those English keys are filled in on a schedule.

If `olie-fronts` changed, the e2e tests in section 3 cover the requested frontend behavior, or you say which case could not be automated and why.

## 6. Out of scope

- Do not fix the author's code.
- Do not move the card. `workflow.md` decides the stage after the report.
- Do not treat a local-only success as the production check. That check is `Revisão de Produção`.
- Do not apply `recommendation.md`. This pass is a review, not a search for extra work.

## 7. Report

- Card {{ code }}.
- Repositories and branches reviewed.
- Whether the implementation matches the card, with the requirement that failed or passed.
- Contrast result for light and dark themes.
- E2E tests added or extended, and the 'main' commit if one was pushed.
- Checks that did not run, and why.

A failed requirement is a failed review. Do not call the card ready for 'validação' while one remains open.
