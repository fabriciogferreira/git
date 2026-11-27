# televisao/ — projeto Televisão no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` | **Sim** |
| Overlay de mídia | `overlay/` (`cursor/` vira `.cursor` no clone) | **Sim** |
| Análises de mídia | `cards/{CARD_CODE}/{MEDIA_ID}.md` | **Sim** |
| E2E Playwright | `televisao-front-e2e/`, `televisao-meet-front-e2e/` | **Sim** |
| Clones | `televisao-api/`, `televisao-front/`, `televisao-meet-*` | **Não** |

Compose fica no api (`televisao-api`). Setup: `./project-setup.sh televisao`.

Host-cards + sandboxes (testes/mutation/e2e em paralelo): `sandbox/README.md` e `~/git/bin/workvm-sandbox` / `workvm-host-card`.
