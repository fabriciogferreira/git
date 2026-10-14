---
name: olie-project-video-conversion
description: >-
  Converts video media from Olie project content via the host vid2agent-code API
  (POST /api/conversions), saves Markdown under ~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md,
  and reuses that file on later passes instead of reconverting. Never post video,
  image, or audio analysis into project content. Use when reading card videos or
  when a card returns to in-progress after review.
---

# Olie project video conversion (vid2agent)

When project content includes **video** messages, turn each video into **text documentation**. Persist it under the card folder so a correction pass does **not** reconvert the same media.

Conversion runs on WorkVM **vid2agent-code** (VLM on the physical host). Call the HTTP API only — do **not** install vid2agent/Ollama in the Olie VM.

## Policy (tech lead)

**Do not send image, video, or audio analysis into the Olie project content.**

- **Forbidden:** `save-media-tool` (or any MCP write) with conversion markdown, transcription, or analysis from video / image / audio.
- **Allowed:** convert via API, save under `~/git/olie/cards/{CARD_CODE}/`, show in chat, use while implementing.

## Local store (idempotency)

```text
~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md
```

Same convention as `olie-project-image-analysis` (one file per media id).

| Rule | Detail |
| --- | --- |
| If the file **exists** and is non-empty | **Do not** reconvert. `Read` it and use that Markdown |
| If the file is **missing** | Download → POST API → **write** the file |
| Reconvert only | When the user explicitly asks to redo that media — then overwrite |
| Meta-repo `~/git` | **Commit and push** these `.md` files on the meta-repo |
| Company remotes | **Never** commit them inside product clones |

## Language

- Skill instructions and agent reasoning: English is fine.
- Metadata / titles you add: Brazilian Portuguese (`pt-BR`).
- Keep the API `markdown` structure; do not invent UI absent from the video.
- Keep technical tokens unchanged.

## When to run

1. Fetch project media and find videos you need, **or**
2. The user asks to convert / understand a card video, **or**
3. Card returns to `in-progress` / correction — load `~/git/olie/cards/{CARD_CODE}/*.md` first.

## Tools

| Step | Tool |
| --- | --- |
| List content | MCP `get-project-media-tool` |
| Load prior conversion | Read `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` if present |
| Download | HTTP GET `file_url` |
| Convert | `curl` POST vid2agent API |
| Save | Write local path above |
| Publish to project | **Never** |

## API (stable URLs)

From another WorkVM (SLIRP): `http://10.0.2.2:18080/api/conversions`  
From the physical host: `http://127.0.0.1:18080/api/conversions`

```bash
curl -sS --fail-with-body --max-time 600 \
  --location 'http://10.0.2.2:18080/api/conversions' \
  --form 'video=@"/absolute/path/to/file.mp4"'
# Expect HTTP 200 and JSON: { "markdown": "..." }
```

Multipart field name: **`video`** (prefer mp4). On connection failure, report blocker (vid2agent VM / hostfwd); do not reinstall in this VM.

## Identify videos

- `extension` in `mp4`, `webm`, `mov`, `mkv`, `avi`, and/or
- `file_url` points to a video and `text` is null/empty, and/or
- MIME / name indicates video

Collect: `id`, `name`, `technical_name`, `extension`, `file_url`, `created_at`, `user`, `project_id`.

## Workflow (per video)

```
Video conversion progress:
- [ ] Fetch / refresh project media
- [ ] Resolve CARD_CODE + MEDIA_ID
- [ ] If ~/git/olie/cards/CARD_CODE/MEDIA_ID.md exists → Read and skip convert
- [ ] Else: download → POST API → write file
- [ ] Use file in chat / implementation
- [ ] Confirm: nothing written to project content
```

### 1. Reuse or convert

1. If `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` exists → Read; stop for this video.
2. Else download `file_url` to `/tmp/olie-video-MEDIA_ID.mp4` (refresh media once on 403/404).
3. POST multipart; require JSON key `markdown`.

### 2. File body

Saved file **must** start with:

```markdown
# Conversão do vídeo

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
| API | `http://10.0.2.2:18080/api/conversions` |
| Arquivo local | `~/git/olie/cards/CARD_CODE/MEDIA_ID.md` |

```

Then append the API `markdown` **as returned**.

### 3. Present

Tell the user which ids were **loaded from disk** vs **newly converted**, and the path under `~/git/olie/cards/{CARD_CODE}/`. Do not call `save-media-tool`.

After writing **new** conversion files, remind (or commit if asked) on the meta-repo: `git add olie/cards/{CARD_CODE}/` in `~/git`.

## Rules

- **Never** post image / video / audio analysis to project content.
- Prefer the local file over a new API conversion whenever it exists.
- One file **per media id**.
- Do not change host Ollama, GPU, or vid2agent install from this VM.
