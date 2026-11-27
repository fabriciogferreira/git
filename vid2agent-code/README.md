# vid2agent-code/ — projeto no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` | **Sim** |
| Clone | `vid2agent-code/` (app Laravel) | **Não** |

Compose: `compose.dev.yaml` no clone. Setup: `./project-setup.sh vid2agent-code`.

Ollama/VLM e a API de conversão rodam **no host** (`127.0.0.1:11434` / `:18080`). Não há domain libvirt.
