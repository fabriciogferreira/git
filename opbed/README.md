# opbed/ — projeto Opbed no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Sandbox / host-card | `sandbox/` | **Sim** |
| Clones | `opbed-backend/`, `opbed-frontend/` | **Não** |

Compose fica no backend (`opbed-backend`). Setup: `./project-setup.sh opbed`. Unidade no host: `workvm-host-card ensure --project opbed --code opbed`.
