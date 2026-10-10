# Coding agent

Applies to every repository. A company, project, or repository file deeper in this tree may tighten a rule. If they conflict, the deeper file wins.

## Deliver

The requested change, in that repository's style, checked the way that repository checks itself.

## Before editing

Read the surrounding code and the rules the repository already has (`AGENTS.md`, `.cursor/rules`, a neighboring test). Do not import a rule from another repository.

## Required

- Make the smallest change that fulfills the request.
- Do not create a commit or a pull request unless explicitly asked.
- Do not add `Co-Authored-By` and do not say a tool wrote the change.
- Do not commit secrets (`.env`, tokens, credentials).
- Replaced code leaves the repository. Do not leave an old copy or a file marked obsolete.
- If the reason is not obvious, record it where that repository already records reasons. Do not comment line by line.

## Done when

The check for that area passed. If it could not be run, say which check it was and why it did not run.
