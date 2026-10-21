---
name: locav-project-video-conversion
description: >-
  Converts video media from Locav project content via the host vid2agent-code API
  (POST /api/conversions), saves Markdown under ~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md,
  and reuses that file on later passes instead of reconverting. Never post video,
  image, or audio analysis into project content. Use when reading card videos or
  when a card returns to in-progress after review.
---

# Locav project video conversion (vid2agent)

When project content includes **video** messages, turn each video into **text documentation**. Persist it under the card folder so a correction pass does **not** reconvert the same media.

Conversion runs on WorkVM **vid2agent-code** (VLM on the physical host). Call the HTTP API only — do **not** install vid2agent/Ollama in the Locav VM.

## Policy (tech lead)

**Do not send image, video, or audio analysis into the Locav project content.**

- **Forbidden:** `save-media-tool` (or any MCP write) with conversion markdown, transcription, or analysis from video / image / audio.
- **Allowed:** convert via API, save under `~/git/locav/cards/{CARD_CODE}/`, show in chat, use while implementing.

## Local store (idempotency)

```text
~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md
```

Same convention as `locav-project-image-analysis` (one file per media id).

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
3. Card returns to `in-progress` / correction — load `~/git/locav/cards/{CARD_CODE}/*.md` first.

## Tools

| Step | Tool |
| --- | --- |
| List content | MCP `get-project-media-tool` |
| Load prior conversion | Read `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` if present |
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

Multipart field name: **`video`** (prefer mp4).

## If the vid2agent-code API is unreachable (STOP and report)

**Never** work around a missing conversion API. Do **not**:

- transcribe or summarize the audio by hand as a substitute;
- extract frames and "read" the video as a substitute for the conversion;
- install vid2agent / Ollama / any model in this VM (the skill forbids it);
- create the `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` file without a real conversion
  (that file means "conversion done" — a later pass would skip the conversion and use a
  hand-made analysis as if it came from the VLM);
- continue the card as if the conversion had been made.

When the conversion is needed and the API does not answer, **stop the work that depends on
it** and report to the user in the chat:

1. **What you were doing** — media `id`, `name`, and the exact call you made.
2. **The objective error** — the verbatim `curl` output (exit code, HTTP status, message).
3. **The evidence you collected** — the smoke test result and the connectivity checks.
4. **That the fix is on the host side** — the vid2agent-code WorkVM and the hostfwd rule for
   port 18080 live on the physical host; the agent cannot repair them from this VM.
5. **What is still possible** — the rest of the card can go on without the video, or the user
   can fix the host and ask to retry the conversion.

Then **wait for the user**. A partial analysis is not a substitute for the conversion.

Smoke test (same URL the host uses to publish the API):

```bash
curl -sS -m 30 -o /dev/null -w '%{http_code}\n' http://10.0.2.2:18080/
# 200 esperado
```

| Signal | Meaning |
| --- | --- |
| `000` + `curl: (7) Failed to connect … Connection refused` | vid2agent-code is down, or the hostfwd rule for port 18080 is missing on the host |
| timeout / hang | the service answered but the conversion did not finish in time — check the host |
| HTTP 4xx / 5xx | the API answered and rejected the request — report the response body |

Useful evidence to collect before reporting:

```bash
timeout 5 bash -c 'echo > /dev/tcp/10.0.2.2/18080' && echo '18080 aberta' || echo '18080 recusada'
# other host ports (e.g. 11435 for Ollama) tell whether the hostfwd itself works
```

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
- [ ] If ~/git/locav/cards/CARD_CODE/MEDIA_ID.md exists → Read and skip convert
- [ ] Else: download → POST API → write file
        └─ API unreachable → STOP and report the objective error (see the section above)
- [ ] Use file in chat / implementation
- [ ] Confirm: nothing written to project content
```

### 1. Reuse or convert

1. If `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` exists → Read; stop for this video.
2. Else download `file_url` to `/tmp/locav-video-MEDIA_ID.mp4` (refresh media once on 403/404).
3. POST multipart; require JSON key `markdown`.
   - If the connection fails (or the call hangs), **do not** write the `.md` file and **do not**
     continue with a hand-made analysis: stop and report the blocker to the user
     ("If the vid2agent-code API is unreachable").

### 2. File body

Saved file **must** start with:

```markdown
# Conversão do vídeo

## Metadados da mídia (fonte OlieFlowAi)

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
| Arquivo local | `~/git/locav/cards/CARD_CODE/MEDIA_ID.md` |

```

Then append the API `markdown` **as returned**.

### 3. Present

Tell the user which ids were **loaded from disk** vs **newly converted**, and the path under `~/git/locav/cards/{CARD_CODE}/`. Do not call `save-media-tool`.

After writing **new** conversion files, remind (or commit if asked) on the meta-repo: `git add locav/cards/{CARD_CODE}/` in `~/git`.

## Rules

- **Never** post image / video / audio analysis to project content.
- Prefer the local file over a new API conversion whenever it exists.
- One file **per media id**.
- Do not change host Ollama, GPU, or vid2agent install from this VM.
- When the API is unreachable, **stop and report the objective error to the user** and wait.
  Never substitute a hand-made analysis for the conversion, and never create the
  `{MEDIA_ID}.md` file without a real conversion.
