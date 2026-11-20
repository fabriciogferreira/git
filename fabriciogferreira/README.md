# fabriciogferreira/ — portfólio Next no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` (`{{ feature }}`, sem card/PR) | **Sim** |
| Sandbox / host-card | `sandbox/` (`workvm-sandbox --project fabriciogferreira`) | **Sim** |
| Clone | `fabriciogferreira/` (Next.js) | **Não** |

Compose no clone: `docker-compose.yaml` (Node + `npm run dev` na `:3000`). Setup: `./project-setup.sh fabriciogferreira`.

Host-card: `workvm-host-card open --project fabriciogferreira --code fabriciogferreira`.

Produção: Vercel (`fabriciogferreira.vercel.app`). Mutation N/A.
