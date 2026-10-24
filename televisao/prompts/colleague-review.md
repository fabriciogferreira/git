# Colleague Card Review

Review card {{ code }} while it sits in 'QA/CR'. This is a review of someone else's card, not preparation of your own (pre-QA).

If MCP, requests, shell, Docker, or other tooling this prompt assumes will work **fails or stalls too long**: stop, report the objective error, and treat it as a signal that **this prompt needs updating**. Do not silently work around it. Shared detail: `~/git/televisao/prompts/workflow-policy.md`.

## 1. Objective

Decide whether the implementation does what the card requested. Report the result. Do not implement the card.

The card's requirements, acceptance criteria, and the latest version of every project thread are the source of truth. Read the threads with **Reading the project forum** in `~/git/televisao/prompts/workflow-policy.md`. A change that works but does not match the card is not a pass.

## 2. Context

Load the card through `mcp olie-flow-ai`. Read:

- The description, requirements, and acceptance criteria.
- The repositories and branches the author changed.
- The pull requests and the commits on those branches.
- Comments, attachments, and test notes.

Do not review from the card title alone.

## 3. What you may change

Do not edit product repositories. That includes `televisao-api`, `televisao-front`, `televisao-meet-front`, and `televisao-meet-core`.

Playwright lives in the meta-repo (`televisao-front-e2e`, `televisao-meet-front-e2e`). During this review, do **not** commit to product repos or add the missing specs yourself. If frontend coverage is missing, report the gap.

Do not commit product code, secrets, or `.env` files. Do not open a pull request on a company repository.

## 4. Branches to test

On each company repository the card touches:

1. Find the branch the author created.
2. Check it out so you can run the feature.
3. If that branch does not exist yet, create the name from **Card branch name** in `~/git/televisao/prompts/workflow-policy.md`, from the repository base in `~/git/televisao/prompts/project.md` (`preview`).
4. Do not rename their branch and do not commit on it.

Leave unrelated local changes untouched. If a checkout would overwrite them, stop and report the blocker.

## 5. What to verify

- The behavior matches the card, including the edge cases the card states.
- The pull request contains that behavior and does not smuggle unrelated changes.
- Light and dark theme text contrast both hold on the screens the card changes.
If `televisao-front` or `televisao-meet-front` changed, the matching meta-repo Playwright suite must create or edit a spec for the requested frontend behavior. Missing coverage is a failed review, unless you state which case could not be automated and why. Do not add the specs yourself.

If `televisao-api` tests were added or edited and Pest is installed, those files use that Pest. A new PHPUnit test class, or a PHPUnit file the card edited and left as PHPUnit while Pest is installed, is a failed review. Untouched PHPUnit files are not a defect. Do not convert them yourself. If Pest is not installed, do not fail the review for PHPUnit tests.

## 6. Out of scope

- Do not fix the author's code.
- Do not move the card. Report the result; the user (or a later workday paste) decides the next stage.
- Do not treat a local-only success as the production check. That check is 'Revisão de produção'.
- Do not search for related improvements in this pass. This is a review only.

## 7. Report

- Card {{ code }}.
- Repositories and branches reviewed.
- Whether the implementation matches the card, with the requirement that failed or passed.
- Contrast result for light and dark themes.
- If `televisao-front` or `televisao-meet-front` changed, whether the matching Playwright suite created or edited a spec for that behavior, or which case could not be automated and why.
- If `televisao-api` tests changed and Pest is installed, whether new or edited files use that Pest, or which edited file is still PHPUnit.
- Checks that did not run, and why.

A failed requirement is a failed review. Do not call the card ready for 'Validação' while one remains open.
