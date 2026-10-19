# Overlay Locav

Skills de mídia que não podem ir no remoto da empresa. No login, `cursor/` vira `.cursor` no clone (`workvm_apply_files`). As duas árvores (`LocavApi` e `locav-front`) são a mesma skill, para o agente achar o arquivo no clone em que estiver.

O remoto do Locav não ignora `.cursor`, e essa linha não entra no `.gitignore` de lá. Cada `project-setup` e cada login gravam `/.cursor` em `.git/info/exclude` do clone. A pasta continua no disco e some do Source Control.

| Skill | Problema |
| --- | --- |
| `locav-project-image-analysis` | Imagem do card não vira texto. A análise vai para `~/git/locav/cards/{CARD_CODE}/{MEDIA_ID}.md` e não entra no conteúdo do projeto. |
| `locav-project-video-conversion` | Vídeo do card não vira texto. A conversão usa a API do vid2agent no host e grava no mesmo caminho. |
