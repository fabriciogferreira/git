---
name: olie-project-video-conversion
description: >-
  Converts video media from Olie project content into structured Markdown via the
  host-exposed vid2agent-code API (POST /api/conversions), then posts the result
  back into the same project. Skips videos that already have a conversion marker.
  Use when reading DOP/card project media that includes video, when the user asks
  to document a screen recording for agents, or when implementing a card that has
  undocumented video attachments.
---

# Olie project video conversion (vid2agent)

When project content includes **video** messages, turn each video into **text documentation** on the same project so future agents can reason without re-watching the recording.

Conversion runs on the WorkVM **vid2agent-code** (Laravel + VLM on the physical host). This skill only calls the HTTP API — do **not** install vid2agent/Ollama in the Olie VM.

## Language

- Skill instructions and agent reasoning: English is fine.
- **Posted project content must be Brazilian Portuguese (`pt-BR`)** for any prose you add around the API markdown (titles, metadata table labels). See also `olie-project-content-language`.
- Keep the API `markdown` body structure; do not invent UI that was not in the video.
- Keep technical tokens unchanged: markers, UUIDs, codes, URLs, file names.

## When to run

Run this workflow whenever you:

1. Fetch project media (`get-project-media-tool`) and find video items, **or**
2. The user asks to convert / document a card video for AI agents.

Do **not** wait for an explicit “run the skill” if you are already reading card content that contains undocumented videos — convert them as part of understanding the card.

## Tools

| Step | Tool |
| --- | --- |
| List content | MCP `get-project-media-tool` with `project_identifier` (CODE or UUID) |
| Download video | HTTP GET `file_url` (or local path under `docs/` if already saved) |
| Convert | `curl` POST to vid2agent API (below) |
| Publish | MCP `save-media-tool` with `project_identifier` + `text` (type 1 only) |

Discover MCP schemas via `GetDynamicTools` before calling if needed.

## API (stable URLs)

From **any other WorkVM** on the same physical host (SLIRP / `10.0.2.2`):

```text
http://10.0.2.2:18080/api/conversions
```

From the physical host itself: `http://127.0.0.1:18080/api/conversions`.

```bash
curl -sS --location 'http://10.0.2.2:18080/api/conversions' \
  --form 'video=@"/absolute/path/to/file.mp4"'
# Expect HTTP 200 and JSON: { "markdown": "..." }
```

- Multipart field name: **`video`** (mp4).
- Timeout: videos can take minutes (VLM on host). Use a generous curl `--max-time` (e.g. 600).
- If connection fails: the vid2agent-code VM may be down, or hostfwd `:18080` missing — tell the user; do not reinstall the stack in this VM.

## Identify videos

Treat a media item as a **video** when any of these hold:

- `extension` in `mp4`, `webm`, `mov`, `mkv`, `avi`, and/or
- `file_url` clearly points to a video and `text` is null/empty, and/or
- MIME / name indicates video

Collect for each: `id`, `name`, `technical_name`, `extension`, `file_url`, `created_at`, `user` (if present), `project_id`.

Prefer **mp4** for the API. If the file is another container and conversion fails, report the error; do not pretend success.

## Idempotency — do not re-convert

Before converting video `MEDIA_ID`, scan **all type-1 (text) media** on the same project.

Skip if any text body contains:

```
[olie-video-conversion:MEDIA_ID]
```

Also treat as already converted if a text message clearly has both:

- heading that marks a video conversion for agents, and
- the same media id in a metadata table

If already present → **skip** (do not call `save-media-tool` again for it).

## Workflow (per undocumented video)

```
Video conversion progress:
- [ ] Fetch / refresh project media
- [ ] List video ids
- [ ] For each video: check marker → skip or convert
- [ ] Download video to a temp path (from file_url)
- [ ] POST multipart to vid2agent API
- [ ] Prepend metadata + marker to returned markdown
- [ ] save-media-tool → project content
- [ ] Confirm marker on re-fetch (optional)
```

### 1. Download

1. Refresh media if needed (`get-project-media-tool`).
2. Download `file_url` to a local temp file (e.g. `/tmp/olie-video-MEDIA_ID.mp4`).
3. Signed URLs expire — on 403/404, refresh media once and retry.

### 2. Convert

```bash
curl -sS --fail-with-body --max-time 600 \
  --location 'http://10.0.2.2:18080/api/conversions' \
  --form "video=@\"/tmp/olie-video-MEDIA_ID.mp4\""
```

Parse JSON; require key `markdown`. On non-200 or missing key → stop for that video and report the error body.

### 3. Build the message body

Posted `text` **must** start with:

```markdown
[olie-video-conversion:MEDIA_ID]

# Conversão do vídeo

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
| API | `http://10.0.2.2:18080/api/conversions` |

```

Then append the API `markdown` string **as returned** (do not strip structure). If you add a short intro, keep it in `pt-BR` and below the metadata table.

### 4. Publish

Call `save-media-tool`:

- `project_identifier`: same project (e.g. `OS-588` / `DOP-…`)
- `text`: full Markdown from step 3

Prefer the **main channel** unless the user asked for a specific channel.

Tell the user briefly: which media ids were converted, which were skipped, and that results were posted to project content.

## Rules

- **Never** re-post a conversion that already has the marker.
- **Only text** via `save-media-tool` — cannot upload the video back.
- Conversion is **documentation for agents**, not product code.
- One posted message **per video**.
- Do not change host Ollama, GPU, or vid2agent install from this VM.
