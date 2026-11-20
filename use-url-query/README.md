# use-url-query/ — projeto no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` (`{{ feature }}`, sem card/PR) | **Sim** |
| Sandbox / host-card | `sandbox/` (`workvm-sandbox --project use-url-query`) | **Sim** |
| Clone | `use-url-query/` | **Não** |

Biblioteca TypeScript + bun. Compose no clone (`docker-compose.yml`, sem porta HTTP). Branch: `main`. Setup: `./project-setup.sh use-url-query`.

Host-card: `workvm-host-card open --project use-url-query --code use-url-query`.

Coverage: ver `sandbox/ORCHESTRATION.md` e `prompts/`. Mutation N/A (sem Pest mutate).
