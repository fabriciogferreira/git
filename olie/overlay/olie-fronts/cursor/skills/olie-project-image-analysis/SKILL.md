---
name: olie-project-image-analysis
description: >-
  Analyzes image media from Olie project content (MCP OlieFlowAi), saves the
  pt-BR Markdown under ~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md, and reuses that
  file on later passes (e.g. correction) instead of re-analyzing. Never post
  image, video, or audio analysis into project content. Use when reading card
  media, documenting screenshots for the task, or returning a card to in-progress.
---

# Olie project image analysis

When project content includes image messages, turn each image into **text documentation** so you can reason without re-opening the screenshot. Persist it on disk under the card folder so a later correction pass does **not** re-analyze the same media.

## Policy (tech lead)

**Do not send image, video, or audio analysis into the Olie project content.**

- **Forbidden:** `save-media-tool` (or any MCP write) with analysis, transcription, or converted markdown derived from image / video / audio.
- **Allowed:** analyze locally, save under `~/git/olie/cards/{CARD_CODE}/`, show the user in chat, use while implementing.

## Local store (idempotency)

Path (WorkVM / meta-repo layout):

```text
~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md
```

Examples: `~/git/olie/DOP-1180/a1b2c3d4-….md`, `~/git/olie/OS-588/…`.

| Rule | Detail |
| --- | --- |
| `{CARD_CODE}` | Project code from the card (e.g. `DOP-1180`) |
| `{MEDIA_ID}` | Media `id` from OlieFlowAi (UUID or whatever the API returns) |
| If the file **exists** and is non-empty | **Do not** re-analyze. `Read` it and use that Markdown |
| If the file is **missing** | Analyze, then **write** the full Markdown to that path (`mkdir -p` the card dir) |
| Re-analyze only | When the user explicitly asks to redo that media — then overwrite the file |
| Meta-repo `~/git` | **Commit and push** these `.md` files on the meta-repo so any WorkVM / a later return of the card still has them |
| Company remotes | **Never** commit them inside `api-main` / `olie-fronts` (wrong remotes) |

## Language

- Skill instructions and agent reasoning: English is fine.
- **Analysis Markdown** (file + chat) must be Brazilian Portuguese (`pt-BR`). See also `olie-project-content-language` (media analysis is not an allowed project write).
- Keep technical tokens unchanged: UUIDs, codes, URLs, file names.

## When to run

1. Fetch project media (`get-project-media-tool`) and find image items you need, **or**
2. The user asks to analyze / understand card images, **or**
3. The card returns to `in-progress` / correction — load existing `~/git/olie/cards/{CARD_CODE}/*.md` first.

Do **not** wait for an explicit “run the skill” if you need the images to understand the card.

## Tools

| Step | Tool |
| --- | --- |
| List content | MCP `get-project-media-tool` |
| Load prior analysis | Read `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` if present |
| Save analysis | Write that path (local only) |
| Publish to project | **Never** — no `save-media-tool` for this workflow |

## Identify images

Treat a media item as an **image** when any of these hold:

- `type === 2` (file/image), and/or
- `extension` in `png`, `jpg`, `jpeg`, `gif`, `webp`, `bmp`, `svg`, and/or
- `file_url` points to an image and `text` is null/empty

Collect: `id`, `name`, `technical_name`, `extension`, `file_url`, `created_at`, `user`, `project_id`.

## Workflow (per image)

```
Image analysis progress:
- [ ] Fetch / refresh project media
- [ ] Resolve CARD_CODE + MEDIA_ID
- [ ] If ~/git/olie/cards/CARD_CODE/MEDIA_ID.md exists → Read and skip analyze
- [ ] Else: Download/Read image → analysis-prompt.md (pt-BR)
- [ ] Write ~/git/olie/cards/CARD_CODE/MEDIA_ID.md
- [ ] Use file in chat / implementation
- [ ] Confirm: nothing written to project content
```

### 1. Reuse or analyze

1. `CARD_CODE` = card code; `MEDIA_ID` = media `id`.
2. If `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` exists → Read it; stop for this image.
3. Otherwise obtain the image (`file_url` / local copy), **Read** with vision, follow **[analysis-prompt.md](analysis-prompt.md)**, produce full Markdown in **pt-BR**.

### 2. File body

Saved file **must** start with:

```markdown
# Análise da imagem

## Metadados da mídia (fonte Olie)

| Campo | Valor |
| --- | --- |
| Projeto | CARD_CODE |
| Media `id` | `MEDIA_ID` |
| `name` | … |
| `technical_name` | … |
| `type` | … |
| `extension` | … |
| `created_at` | … |
| Autor | … (if known) |
| Arquivo local | `~/git/olie/cards/CARD_CODE/MEDIA_ID.md` |

```

Then append the full analysis from `analysis-prompt.md` (through `# Resumo para Coding Agent` / `## Classificação`).

### 3. Present

Tell the user which media ids were **loaded from disk** vs **newly analyzed**, and the path `~/git/olie/cards/{CARD_CODE}/`. Do not call `save-media-tool`.

After writing **new** analysis files, remind (or do, if the user asked to commit) that they belong in the meta-repo: `git add olie/cards/{CARD_CODE}/ && git commit` / push on `~/git`.

## Rules

- **Never** post image / video / audio analysis to project content.
- Prefer the local file over a new vision pass whenever it exists.
- Signed `file_url`s expire — refresh media once and retry download if needed.
- One file **per media id**; do not bundle multiple images in one `.md`.
