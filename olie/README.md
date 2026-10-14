# olie/ — projeto Olie no meta-repo

| O quê | Onde | No meta-repo? |
| --- | --- | --- |
| Definição do projeto | `project.conf`, `post-clone.sh`, `workspace.code-workspace`, compose | **Sim** |
| Overlay Cursor / e2e | `overlay/`, `olie-e2e/` | **Sim** |
| Prompts | `prompts/` | **Sim** |
| Análises de mídia | `cards/{CARD_CODE}/{MEDIA_ID}.md` | **Sim** |
| Clones da empresa | `api-main/`, `olie-fronts/`, … | **Não** |

Setup: `./project-setup.sh olie` (symlink `~/.config/workvm/current` → esta pasta).
