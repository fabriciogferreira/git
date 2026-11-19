# Conversão do vídeo

## Metadados da mídia (fonte Olie)

| Campo | Valor |
| --- | --- |
| Projeto | DOP-1257 |
| Media `id` | `01a1eedd-cb6c-73c3-bf8f-c63cd848b72a` |
| `name` | screenrecording-2026-11-18_10-33-09.mp4 |
| `technical_name` | screenrecording-2026-11-18_10-33-09-10343520261118.mp4 |
| `type` | 2 |
| `extension` | mp4 |
| `created_at` | 2026-11-18T13:34:35.000000Z |
| Autor | Fabrício G. Ferreiraa |
| Fonte | `agent-local (vid2agent unreachable)` |
| API | `http://10.0.2.2:18080/api/conversions` |
| Arquivo local | `~/git/olie/cards/DOP-1257/01a1eedd-cb6c-73c3-bf8f-c63cd848b72a.md` |

## Metadata

file_name: screenrecording-2026-11-18_10-33-09
extension: mp4
duration_in_seconds: 49s
duration_in_minutes: 0m49s
has_audio: false
audio: This video has no sound.

## User context

Validação em produção após o deploy do olie-fronts: tentativa de reproduzir o bug do botão de execução com header compacto (DevTools aberto estreita o viewport). Card voltou de Validação para correção (contador “Quantas vezes voltou para correção” = 1).

## Tab URL

url: https://esolie.olie.ai/projects/funnels?v=kanban&project_funnel=…

## Browser

name: chrome
devtools_open: true

## Objects

buttons:
  - Play / Iniciar execução (rodapé do card no Kanban)
  - Filtros
  - Opções do funil

inputs: []

## Open tabs

- title: OLIE / Funil
  probable_site: esolie.olie.ai
  state: active

## Target

component: button
label: Iniciar execução (ícone play no rodapé do card)
region: cards em QA/CR (ex.: DOP-1276) com DevTools lateral aberto
what: Iniciar ou trocar execução de projeto em layout estreito pós-deploy
pointer: cursor
evidence: ui

## Steps

1. t≈3s: Funil Dev - Olie Principal em Kanban; DevTools Console aberto (403 em rotas `/api/management/...`, também 429 Sentry); viewport estreito pelo painel lateral
2. t≈9–15s: Card DOP-1276 em QA/CR (“imprimir página do Caderno”); timer ativo no header (~00:29–00:36); console com dezenas de issues
3. t≈21s: Tooltip **Iniciar execução** sobre o ícone play do rodapé do card; card sem borda clara de execução ativa própria
4. t≈28–34s: Continua interação no Kanban com DevTools aberto; header permanece no modo com player/timer
5. t≈40–46s: Console ainda com 403 Forbidden e mensagens de permissão; sem evidência clara nos frames de POST de `project-executions` concluído nem de contador/borda claros no card clicado

## Agent notes

- vid2agent em `10.0.2.2:18080` não respondeu (timeout); análise por keyframes + ffprobe + tesseract.
- Ambiente: **produção** `esolie.olie.ai`, não o host-card local.
- Condição de reprodução alinhada ao card: DevTools aberto reduz a largura útil → header compacto (mesmo mecanismo do DOP-1251).
- Já havia execução ativa no MiniNavbarPlayer; o sintoma alvo é falha ao iniciar/trocar execução e/ou ausência de indicadores no card.
- Console mistura 403 de permissão (ex.: áreas de negócio) com o fluxo de execução — tratar como ruído colateral, não como causa documentada no Caderno.
- Esta mídia é a evidência da **volta de Validação** (regressão percebida pós-deploy PR #807 / merge #804).
