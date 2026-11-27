# Host: vid2agent API pronta para Olie

## Status

A API de conversão escuta no host:

```text
http://127.0.0.1:18080/api/conversions
```

- `POST` multipart field `video` (mp4) → JSON `{ "markdown": "..." }`
- Skill no overlay Olie: `olie-project-video-conversion`

## Se algo falhar ou demorar

Se request, shell, API, overlay ou smoke que este prompt assume que funciona **falhar ou demorar demais**: pare. Não contorne em silêncio. Avise o que falhou, o erro objetivo e que **este prompt (ou a premissa) provavelmente precisa ser atualizado**.

## O que fazer no card / host-card Olie

1. Garantir a skill no clone (overlay): `.cursor/skills/olie-project-video-conversion/SKILL.md`  
   Se faltar: puxar meta-repo / reaplicar overlay (`project-start` / sync do overlay olie).
2. Smoke opcional:

```bash
curl -sS -m 30 -o /dev/null -w '%{http_code}\n' http://127.0.0.1:18080/
# 200 esperado
```

3. Ao pedir conversão de vídeo do conteúdo Olie, seguir a skill `olie-project-video-conversion`: API → salvar em `olie/cards/{CARD_CODE}/{MEDIA_ID}.md` → reusar se o arquivo já existir. Commit/push no meta-repo só no `pre-qa.md` (ou fechamento de colleague/production review). **Não** postar no conteúdo do projeto.
