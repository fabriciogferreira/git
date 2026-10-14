# Olie VM: vid2agent API pronta no host

## Status (já feito no host jarvis)

A WorkVM `vid2agent-code` expõe a API de conversão para outras VMs SLIRP:

```text
http://10.0.2.2:18080/api/conversions
```

- `POST` multipart field `video` (mp4) → JSON `{ "markdown": "..." }`
- Validado no host com HTTP 200
- Skill no overlay Olie: `olie-project-video-conversion`

## Se algo falhar ou demorar

Se request, shell, API, overlay ou smoke que este prompt assume que funciona **falhar ou demorar demais**: pare. Não contorne em silêncio. Avise o que falhou, o erro objetivo e que **este prompt (ou a premissa) provavelmente precisa ser atualizado**.

## O que fazer nesta VM (ex.: olie-os-588)

1. Garantir a skill no clone (overlay): `.cursor/skills/olie-project-video-conversion/SKILL.md`  
   Se faltar: puxar meta-repo / reaplicar overlay (`project-start` / sync do overlay olie).
2. Smoke opcional:

```bash
curl -sS -m 30 -o /dev/null -w '%{http_code}\n' http://10.0.2.2:18080/
# 200 esperado
```

3. Ao pedir conversão de vídeo do conteúdo Olie, seguir a skill `olie-project-video-conversion`: API → salvar em `~/git/olie/cards/{CARD_CODE}/{MEDIA_ID}.md` → commit/push no meta-repo → reusar se o arquivo já existir. **Não** postar no conteúdo do projeto.
