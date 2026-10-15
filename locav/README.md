# locav/ — projeto Locav no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Prompts (colar no agente) | `prompts/` | **Sim** |
| Clones | `LocavApi/`, `locav-front/` | **Não** |

Compose fica na API (`LocavApi`); o serviço `frontend` monta o sibling `../locav-front` (nome obrigatório). Branch de origem: `preview`. Setup: `./project-setup.sh locav`.
