# locav/ — projeto Locav no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `start.hook.sh`, `workspace.code-workspace` | **Sim** |
| Prompts (colar no agente) | `prompts/` | **Sim** |
| Overlay Cursor (skills de mídia) | `overlay/` | **Sim** |
| Clones | `LocavApi/`, `locav-front/` | **Não** |

Compose fica na API (`LocavApi`); o serviço `frontend` monta o sibling `../locav-front` (nome obrigatório). Branch de origem: `preview`. Setup: `./project-setup.sh locav`.

`post-clone.sh` só prepara `.env`. Depois do compose, `start.hook.sh` faz `composer install`, migrate, seed e passport no primeiro boot (idempotente se `vendor/` já existir).
