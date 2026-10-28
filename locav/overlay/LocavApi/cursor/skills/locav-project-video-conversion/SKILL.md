---
name: locav-project-video-conversion
description: >-
  Converts video media from Locav project content via the host vid2agent-code API
  (POST /api/conversions), or with agent-local analysis when that API is unreachable.
  Saves Markdown under ~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md and reuses that file
  on later passes instead of reconverting. Never post video, image, or audio analysis
  into project content. Use when reading card videos or when a card returns to
  in-progress after review.
---

# Locav project video conversion (vid2agent)

When project content includes **video** messages, turn each video into **text documentation**. Persist it under the card folder so a correction pass does **not** reconvert the same media.

**Prefer** the WorkVM **vid2agent-code** HTTP API (VLM on the physical host). Call that API only for conversion — do **not** install vid2agent/Ollama in the Locav VM. When the API is unreachable, run **agent-local analysis** (below) into the same store path; do not stop the card for a down conversion VM.

## Policy (tech lead)

**Do not send image, video, or audio analysis into the Locav project content.**

- **Forbidden:** `save-media-tool` (or any MCP write) with conversion markdown, transcription, or analysis from video / image / audio.
- **Allowed:** convert via API or agent-local fallback, save under `~/git/locav/cards/{CARD_CODE}/`, show in chat, use while implementing.

## Local store (idempotency)

```text
~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md
```

Same convention as `locav-project-image-analysis` (one file per media id).

| Rule | Detail |
| --- | --- |
| If the file **exists** and is non-empty | **Do not** reconvert. `Read` it and use that Markdown (API or prior agent-local) |
| If the file is **missing** | Download → try API → on failure, agent-local → **write** the file |
| Reconvert only | When the user explicitly asks to redo that media — then overwrite |
| Meta-repo `~/git` | **Commit and push** these `.md` files on the meta-repo |
| Company remotes | **Never** commit them inside product clones |

## Language

- Skill instructions and agent reasoning: English is fine.
- Metadata / titles you add: Brazilian Portuguese (`pt-BR`).
- Keep the conversion Markdown structure; do not invent UI absent from the video.
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
| Convert (preferred) | `curl` POST vid2agent API |
| Convert (fallback) | Agent-local analysis (ffprobe/ffmpeg frames + Read; see below) |
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

Multipart field name: **`video`** (prefer mp4). Optional form field `context` (max 2000) becomes **User context** in the API markdown.

Smoke test before converting:

```bash
curl -sS -m 30 -o /dev/null -w '%{http_code}\n' http://10.0.2.2:18080/
# 200 esperado
```

| Signal | Meaning |
| --- | --- |
| `000` + `curl: (7) Failed to connect … Connection refused` | vid2agent-code is down, or the hostfwd rule for port 18080 is missing on the host |
| timeout / hang | the service answered but the conversion did not finish in time — check the host |
| HTTP 4xx / 5xx | the API answered and rejected the request — report the response body |

## If the vid2agent-code API is unreachable (agent-local fallback)

**Do not** install vid2agent / Ollama / any model in this VM. **Do** continue the card with an agent-local conversion.

When conversion is needed and the API does not answer (or hangs past a reasonable wait):

1. Report in chat: media `id` / `name`, the exact call, the objective error (exit code, HTTP status, message), and that the host/vid2agent-code may need repair.
2. Download the video (if not already local).
3. Produce the **fixed section Markdown** (see **Conversion Markdown schema**) yourself:
   - **Metadata:** `ffprobe` / file name / extension when available.
   - **Tab URL / Browser / Objects / Open tabs / Target / Steps:** extract keyframes with `ffmpeg` when available; `Read` those image frames; fill only what is visible. Omit sections without evidence.
   - **Speech / Non-speech audio:** only if you can inspect audio with available tools; otherwise omit.
   - **User context:** card note or POST `context` if known; otherwise omit.
   - **Agent notes:** include that vid2agent was unreachable and that sections are agent-local.
4. Write `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` with the usual header, provenance `Fonte: agent-local (vid2agent unreachable)`, then the schema body.
5. Use that file for implementation. Never post it to project content.

Useful connectivity evidence (optional, before/after reporting):

```bash
timeout 5 bash -c 'echo > /dev/tcp/10.0.2.2/18080' && echo '18080 aberta' || echo '18080 recusada'
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
- [ ] Else: download → POST API
        └─ API unreachable → agent-local analysis → write file (same path)
- [ ] Use file in chat / implementation
- [ ] Confirm: nothing written to project content
```

### 1. Reuse or convert

1. If `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` exists → Read; stop for this video.
2. Else download `file_url` to `/tmp/locav-video-MEDIA_ID.mp4` (refresh media once on 403/404).
3. Smoke-test / POST multipart; require JSON key `markdown` on success.
4. On connection failure, timeout, or non-recoverable host error → agent-local fallback (section above). Still write the `.md` file.

### 2. File body

Saved file **must** start with:

```markdown
# Conversão do vídeo

## Metadados da mídia (fonte Locav)

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
| Fonte | `vid2agent API` **or** `agent-local (vid2agent unreachable)` |
| API | `http://10.0.2.2:18080/api/conversions` |
| Arquivo local | `~/git/locav/cards/CARD_CODE/MEDIA_ID.md` |

```

Then append:

- **API success:** the API `markdown` **as returned**.
- **Agent-local:** the **Conversion Markdown schema** body (sections only when you have evidence).

### 3. Present

Tell the user which ids were **loaded from disk** vs **newly converted** (API vs agent-local), and the path under `~/git/locav/cards/{CARD_CODE}/`. Do not call `save-media-tool`.

After writing **new** conversion files, remind (or commit if asked) on the meta-repo: `git add locav/cards/{CARD_CODE}/` in `~/git`.

## Conversion Markdown schema

A conversão devolve um Markdown em seções fixas, nesta ordem. Cada bloco só entra quando a pipeline tem o dado. Com o VLM ligado, o modelo preenche só as seções de G2 e não pode reescrever Metadata, User context, Tab URL, Speech, Non-speech audio nem Browser.

Com **agent-local**, o agente preenche só as seções para as quais tem evidência (frames, áudio, contexto). Não invente UI, fala ou abas ausentes no vídeo.

```markdown
## Metadata

file_name: feature
extension: mp4
duration_in_seconds: 90s
duration_in_minutes: 1m30s
has_audio: true
audio: This video has no sound.

## User context

Change the Salvar button background to blue.

## Tab URL

url: https://example.com/login

## Speech

- t=0s speaker=A: Click login
- t=4s speaker=B: Agora abra o dashboard

## Non-speech audio

- t=12s end=18s kind=media
- t=19.2s end=19.4s kind=ui_sound

## Browser

name: chrome
devtools_open: true

## Objects

buttons:
  - Login
  - Cancel

inputs:
  - label: Email
    placeholder: Enter your email
  - label: Password
    value: "********"

## Open tabs

- title: OLIE | Menções
  icon: orange square with a white stylized mark
  probable_site: olie.ai
  state: active
- title: null
  icon: rounded red square with a white play triangle
  probable_site: youtube.com
  state: pinned

## Target

component: button
label: Salvar
region: Mentions toolbar
what: Change background color
pointer: cursor
evidence: both

## Steps

1. t=1s: Open the Mentions page filters
2. t=4s: Click Salvar

## Agent notes

- ...
```

| Seção | Quando entra | Campos |
| --- | --- | --- |
| **Metadata** | Sempre | `file_name`, `extension`, `duration_in_seconds` (`Ns`), `duration_in_minutes` (`NmNs`), `has_audio`. A linha `audio: This video has no sound.` só quando `has_audio: false`. |
| **User context** | Campo `context` no `POST` (máx. 2000) | Texto livre, eco exato. |
| **Tab URL** | OCR da barra de endereço | Uma URL: `url:`. Duas ou mais: `- t=Xs: https://…`. |
| **Speech** | Há áudio e fala | `- t=Xs: texto`. `speaker=A\|B` quando há diarização. |
| **Non-speech audio** | Há áudio e som fora da fala | `- t=Xs end=Ys kind=media\|ui_sound`. `ui_sound` é um burst de até 0,5 s. |
| **Browser** | Marca ou DevTools conhecidos | `name: chrome\|firefox\|edge\|brave\|opera\|safari\|chromium`. `devtools_open: true\|false`. Sem chrome de navegador, a seção some. |
| **Objects** | VLM, ou OCR se o VLM estiver desligado | `buttons:` (rótulo) e `inputs:` (`label`, `placeholder`, `value`). Senha mascarada vai entre aspas. Sem o VLM, só este bloco de G2. |
| **Open tabs** | Só com VLM | Por aba: `title`, `icon`, `probable_site`, `state` (`active\|pinned\|inactive\|normal`). Se a faixa muda: grupos `- t=Xs:`. |
| **Target** | Só com VLM, e só se o alvo for claro | `component` (`button\|input\|link\|text\|icon\|image\|sidebar_item\|other`), `label`, `region`, `what`, `pointer` (`cursor\|highlight\|gesture\|speech_only`), `evidence` (`speech\|ui\|both`). |
| **Steps** | Só com VLM, e só se houver um procedimento | Lista numerada `N. t=Xs: …`, no máximo 8. |
| **Agent notes** | Só com VLM | Notas livres para o agente de código. |

On **agent-local**, treat “Só com VLM” sections as allowed when frame evidence is clear; omit Target / Steps / Open tabs / Agent notes when unclear. Always add an Agent notes bullet that vid2agent was unreachable when using the fallback.

## Rules

- **Never** post image / video / audio analysis to project content.
- Prefer the local file over a new conversion whenever it exists.
- One file **per media id**.
- Prefer the vid2agent API; fall back to agent-local when it is unreachable.
- Do not change host Ollama, GPU, or vid2agent install from this VM.
