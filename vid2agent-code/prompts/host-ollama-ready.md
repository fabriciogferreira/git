# Guest: host Ollama pronto — amarrar vid2agent-code

## Status do host (já feito — não reinstalar Ollama)

No **host físico** (jarvis) o Ollama sob demanda para esta WorkVM está pronto:

- Display do host na **iGPU**; RTX 5060 só para compute (sem passthrough).
- Ollama **não** sobe no boot; sobe/para com a VM `vid2agent-code` (libvirt `qemu:///session` hook).
- Escuta em `127.0.0.1:11434` no host; a guest alcança via SLIRP em `10.0.2.2`.
- Modelo VLM disponível: **`qwen2.5vl:3b`** (Q4_K_M, vision).  
  (`qwen2.5vl:7b` falhou no pull com `EOF` neste host — não bloquear nisso.)
- Validado **de dentro do container** na guest:

```bash
docker exec vid2agent-code-php-fpm curl -sS http://10.0.2.2:11434/api/tags
# retorna qwen2.5vl:3b com capabilities including "vision"
```

**Fora de escopo neste prompt:** instalar/reconfigurar Ollama no host, GPU passthrough, APIs pagas.

## Se algo falhar ou demorar

Se request, shell, Docker, MCP ou smoke que este prompt assume que funciona **falhar ou demorar demais**: pare. Não contorne em silêncio. Avise o que falhou, o erro objetivo e que **este prompt (ou a premissa) provavelmente precisa ser atualizado**.

## Objetivo neste workspace (guest / app)

1. Garantir `.env` do Laravel (compose) com:

```env
VIDEO_LLM_ENABLED=true
VIDEO_LLM_BASE_URL=http://10.0.2.2:11434/v1
VIDEO_LLM_MODEL=qwen2.5vl:3b
VIDEO_LLM_API_KEY=ollama
VIDEO_LLM_TIMEOUT=300
```

2. Se o app ainda não consome essas variáveis: implementar a integração OpenAI-compatible (chat/completions multimodal) apontando para `VIDEO_LLM_BASE_URL` / `VIDEO_LLM_MODEL`, sem hardcode de URL.
3. Reiniciar serviços Docker que leem `.env` se necessário (`php-fpm` / `workspace`).
4. Fazer um smoke test mínimo da feature (ou do client HTTP) contra o endpoint já acessível.

## Valores finais (copiar)

| Chave | Valor |
| --- | --- |
| `VIDEO_LLM_BASE_URL` | `http://10.0.2.2:11434/v1` |
| `VIDEO_LLM_MODEL` | `qwen2.5vl:3b` |
| `VIDEO_LLM_API_KEY` | `ollama` |

Notas no host (referência): `~/.local/share/doc/ollama-workvm.md`
