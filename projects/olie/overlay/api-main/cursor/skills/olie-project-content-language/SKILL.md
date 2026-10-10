---
name: olie-project-content-language
description: >-
  Requires Brazilian Portuguese for any text created, updated, or registered in
  Olie project content via MCP OlieFlowAi (save-media-tool, edit-project-tool,
  set-form-answers-tool, create-project description fields, etc.). Use whenever
  writing to a DOP/card project, posting media text, or editing form answers on
  a project.
---

# Olie project content language

## Rule

Any content the agent **writes, creates, updates, or registers** on an Olie **project** (card) through MCP must be in **Brazilian Portuguese (`pt-BR`)**.

This includes, but is not limited to:

- `save-media-tool` (`text`)
- `edit-project-tool` / `create-project-tool` / `quick-create-project-tool` / `clone-project-tool` (name, description, and other user-facing text fields)
- `set-form-answers-tool` (answer values that are prose)
- Image-analysis documentation posted to project content (see `olie-project-image-analysis`)

## Does not apply to

- Agent chat replies to the user (follow the user’s language)
- Repo files under `.cursor/`, code, commits, PRs, and local `docs/` plans (English unless the user asks otherwise)
- Verbatim quotes of existing content (preserve original language)
- Codes, IDs, URLs, enum values, branch names, and technical identifiers

## How to apply

1. Draft user-facing project text in `pt-BR`.
2. Keep markers/technical tokens unchanged (e.g. `[olie-image-analysis:MEDIA_ID]`, UUIDs, codes like `DOP-1180`).
3. If the user pastes English that must be stored on the project, translate to `pt-BR` unless they explicitly ask to keep English on the card.
