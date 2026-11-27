# Host: Ollama pronto — amarrar vid2agent-code

## Status do host (já feito — não reinstalar Ollama)

No **host** (jarvis):

- Ollama escuta em `127.0.0.1:11434`.
- Modelo VLM: **`qwen2.5vl:3b`** (Q4_K_M, vision).
- Smoke:

```bash
curl -sS http://127.0.0.1:11434/api/tags
# retorna qwen2.5vl:3b com capabilities including "vision"
```

**Fora de escopo neste prompt:** instalar/reconfigurar Ollama, GPU passthrough, APIs pagas.

## Se algo falhar ou demorar

Se request, shell, Docker, MCP ou smoke que este prompt assume que funciona **falhar ou demorar demais**: pare. Não contorne em silêncio. Avise o que falhou, o erro objetivo e que **este prompt (ou a premissa) provavelmente precisa ser atualizado**.

## Objetivo neste workspace (app no host)

1. Garantir `.env` do Laravel (compose) com:

```env
VIDEO_LLM_ENABLED=true
VIDEO_LLM_BASE_URL=http://127.0.0.1:11434/v1
VIDEO_LLM_MODEL=qwen2.5vl:3b
VIDEO_LLM_API_KEY=ollama
VIDEO_LLM_TIMEOUT=300
```

2. Se o app ainda não consome essas variáveis: implementar a integração OpenAI-compatible apontando para `VIDEO_LLM_BASE_URL` / `VIDEO_LLM_MODEL`, sem hardcode de URL.
3. Reiniciar serviços Docker que lêem `.env` se necessário.
4. Smoke mínimo da feature (ou do client HTTP) contra o endpoint.

## Valores finais (copiar)

| Chave | Valor |
| --- | --- |
| `VIDEO_LLM_BASE_URL` | `http://127.0.0.1:11434/v1` |
| `VIDEO_LLM_MODEL` | `qwen2.5vl:3b` |
| `VIDEO_LLM_API_KEY` | `ollama` |
