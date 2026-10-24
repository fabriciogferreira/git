# boilerplate-next/ — projeto boilerplate Next no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `workspace.code-workspace` | **Sim** |
| Clone | `boilerplate-next/` (app Next) | **Não** |

Compose: `compose.yaml` no clone (guia Docker, `output: "standalone"`). O login sobe só `nextjs-dev`; produção é `docker compose --profile prod up nextjs-prod-standalone`. Sem `post-clone.sh`: não há bootstrap. Setup: `./project-setup.sh boilerplate-next`.

Escolhas do container e desta amarração: `boilerplate-next/DECISIONS.md` no clone.
