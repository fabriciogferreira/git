# vid2agent-code/ — projeto no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace` | **Sim** |
| Prompts | `prompts/` | **Sim** |
| Clone | `vid2agent-code/` (app Laravel) | **Não** |

Compose: `compose.dev.yaml` no clone. Setup: `./project-setup.sh vid2agent-code`.

Ollama/VLM no host; API de conversão para outras WorkVMs em `http://10.0.2.2:18080`.
