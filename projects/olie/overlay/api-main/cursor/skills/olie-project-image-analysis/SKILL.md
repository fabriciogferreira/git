---
name: olie-project-image-analysis
description: >-
  Analyzes image media from Olie project content (MCP OlieFlowAi), produces a
  structured Markdown analysis for coding agents in Brazilian Portuguese, and
  posts it back into the same project content. Skips images that already have an
  analysis. Use when reading DOP/card project media via get-project-media-tool,
  when the user asks to document screenshots on a card, or when implementing a
  card that has image attachments without prior image-analysis messages.
---

# Olie project image analysis

When project content includes image messages, turn each image into **text documentation** on the same project so future agents can reason without re-opening the screenshot.

## Language

- Skill instructions and agent reasoning: English is fine.
- **Posted project content must be Brazilian Portuguese (`pt-BR`)** — analysis body, metadata labels in the posted table, section titles below, and prose. See also `olie-project-content-language`.
- Keep technical tokens unchanged: markers, UUIDs, codes, URLs, file names.

## When to run

Run this workflow whenever you:

1. Fetch project media (`get-project-media-tool`) and find image items, **or**
2. The user asks to analyze / document card images for AI agents.

Do **not** wait for an explicit “run the skill” if you are already reading card content that contains undocumented images — document them as part of understanding the card.

## Tools

| Step | MCP tool (OlieFlowAi) |
| --- | --- |
| List content | `get-project-media-tool` with `project_identifier` (CODE or UUID) |
| Publish analysis | `save-media-tool` with `project_identifier` + `text` (type 1 only) |

Discover schemas via `GetDynamicTools` before calling if needed.

## Identify images

Treat a media item as an **image** when any of these hold:

- `type === 2` (file/image), and/or
- `extension` in `png`, `jpg`, `jpeg`, `gif`, `webp`, `bmp`, `svg`, and/or
- `file_url` points to an image and `text` is null/empty

Collect for each image: `id`, `name`, `technical_name`, `extension`, `file_url`, `created_at`, `user` (if present), `project_id`.

## Idempotency — do not re-analyze

Before analyzing image `MEDIA_ID`, scan **all type-1 (text) media** on the same project.

Skip the image if any text body contains the marker:

```
[olie-image-analysis:MEDIA_ID]
```

Also treat as already analyzed (legacy / manual docs) if a text message clearly contains both:

- heading `# Análise da imagem`, and
- the same media id (e.g. table row `Media \`id\` | \`MEDIA_ID\``)

If already present → **skip** that image (do not call `save-media-tool` again for it).

## Workflow (per undocumented image)

Copy and track:

```
Image analysis progress:
- [ ] Fetch / refresh project media
- [ ] List image ids
- [ ] For each image: check marker → skip or analyze
- [ ] Download or Read the image (file_url / local copy)
- [ ] Run analysis prompt (see analysis-prompt.md) — output in pt-BR
- [ ] Prepend metadata + marker
- [ ] save-media-tool → project content
- [ ] Confirm marker appears on re-fetch (optional)
```

### 1. Analyze

1. Obtain the image bytes/URL (`file_url` from media, or a local copy under `docs/` if already saved).
2. **Read the image** with the Read tool (vision) so the analysis is based on pixels, not guesses.
3. Follow **[analysis-prompt.md](analysis-prompt.md)** exactly (sections, rules, classification). Do not invent UI that is not visible.
4. Produce the full analysis Markdown in **Brazilian Portuguese**.

### 2. Build the message body

Posted `text` **must** start with (Portuguese labels in the metadata table):

```markdown
[olie-image-analysis:MEDIA_ID]

# Análise da imagem

## Metadados da mídia (fonte Olie)

| Campo | Valor |
| --- | --- |
| Projeto | CODE_OR_UUID |
| Media `id` | `MEDIA_ID` |
| `name` | … |
| `technical_name` | … |
| `type` | … |
| `extension` | … |
| `created_at` | … |
| Autor | … (if known) |

```

Then append the full analysis Markdown required by `analysis-prompt.md` (from `# Análise da imagem` sections through `# Resumo para Coding Agent` / `## Classificação`), still in `pt-BR`.

If the project has a related client text message (type 1 describing the card), put it **verbatim** under **Mensagem original do cliente**. Otherwise use the prompt’s fallback line.

### 3. Publish

Call `save-media-tool`:

- `project_identifier`: same project (e.g. `DOP-1180`)
- `text`: full Markdown from step 2 (`pt-BR`)

Prefer the **main channel** (omit `channel_id` / `channel_name`) unless the user asked for a specific channel.

Tell the user briefly (in their language): which media ids were analyzed, which were skipped, and that analyses were posted to project content.

## Rules

- **Never** re-post an analysis for an image that already has a marker (or equivalent legacy analysis).
- **Only text** via `save-media-tool` — cannot upload images back.
- Analysis is **documentation for agents**, not product code. Do not implement UI solely from the screenshot; use it as investigation context (see prompt classification).
- Signed `file_url`s expire — if download fails, refresh media with `get-project-media-tool` and retry once.
- Keep one posted message **per image** (do not bundle multiple images in one analysis).

## Optional local copy

Saving PNGs under `docs/` is optional and does **not** replace posting the analysis to the project. Prefer project content as the source of truth for other agents.
