# Overlay Televisão

Skills de mídia e MCP local que não podem ir no remoto da empresa. No login, `cursor/` vira `.cursor` no clone (`workvm_apply_files`). As quatro árvores de skill são a mesma, para o agente achar o arquivo no clone em que estiver.

`televisao-api/cursor/mcp.json` — Laravel Boost via `workvm-docker-mcp.sh` no container `televisao-backend` (`WORKDIR` `/srv`).

O remoto da Televisão pode não ignorar `.cursor`. Cada `project-setup` e cada login gravam `/.cursor` em `.git/info/exclude` do clone. A pasta continua no disco e some do Source Control.

A análise não entra no conteúdo do card. Vai para `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md` e é commitada neste meta-repo, como na Olie.

| Skill | Problema |
| --- | --- |
| `televisao-project-image-analysis` | Imagem do card não vira texto no projeto. A análise fica em `~/git/televisao/cards/{CARD_CODE}/{MEDIA_ID}.md`. |
| `televisao-project-video-conversion` | Vídeo do card não vira texto no projeto. A conversão usa a API do vid2agent no host e grava no mesmo caminho. |
