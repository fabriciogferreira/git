# use-url-query/ — projeto no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` (`{{ feature }}`, sem card/PR) | **Sim** |
| Sandbox / host-card | `sandbox/` (`workvm-sandbox --project use-url-query`) | **Sim** |
| Clone (lib) | `use-url-query/` | **Não** |
| Clone (demo web) | `use-url-query-demo-web/` | **Não** |
| Clone (demo API) | `use-url-query-demo-api/` | **Não** |

Biblioteca TypeScript + bun; demos públicos Next + Laravel (Spatie) para o recrutador testar. Branch: `main`. Setup: `./project-setup.sh use-url-query`.

Host-card (`workvm-host-card open --project use-url-query --code use-url-query`) sobe **os três**:
- lib bun
- demo-api (nginx → `:port_base`)
- demo-web (Next → `:port_base+1`)

Coverage: ver `sandbox/ORCHESTRATION.md` e `prompts/`. Mutation N/A (sem Pest mutate).
