# boilerplate-laravel/ — projeto boilerplate Laravel no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` (`{{ feature }}`, sem card/PR) | **Sim** |
| Sandbox / host-card | `sandbox/` (`workvm-sandbox --project boilerplate-laravel`) | **Sim** |
| Clone | `boilerplate-laravel/` (app Laravel) | **Não** |

Compose local: `compose.dev.yaml` no clone. Setup: `./project-setup.sh boilerplate-laravel`.

Host-card: `workvm-host-card open --project boilerplate-laravel --code boilerplate-laravel`.

Mutation/coverage: ver `sandbox/ORCHESTRATION.md` e `prompts/`.
