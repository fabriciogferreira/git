# televisao/ — projeto Televisão no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| E2E Playwright | `televisao-front-e2e/`, `televisao-meet-front-e2e/` | **Sim** |
| Clones | `televisao-api/`, `televisao-front/`, `televisao-meet-*` | **Não** |

Compose fica no api (`televisao-api`). Setup: `./project-setup.sh televisao`.
