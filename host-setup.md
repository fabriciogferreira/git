# Setup do host

O host (Hyprland, fone no Fifine, monitor DP-1) ficou sem screenshot e com volume irregular. Este arquivo é o mapa do que foi instalado e configurado para isso. Não descreve as WorkVMs.

O que vale em toda VM nova está no `vm-setup.sh` e no `.config/`. O áudio do Fifine fica só nesta máquina (`~/.config/easyeffects/`).

## Máquina

| Peça | O que é |
| --- | --- |
| Sessão | Hyprland (Wayland), PipeWire 1.6.9, WirePlumber 0.5.18 |
| Monitor real | `DP-1`, 1920×1080 @ 144 Hz (HKM CTR24E-BL01) |
| Saída de vídeo extra | `HDMI-A-5`, 640×480, sem EDID. Desligada |
| Fone | Saída analógica do microfone USB Fifine K690 |
| Volume do fone | 40% no sink do Fifine. Fica depois dos efeitos |

## Pacotes

| Pacote | Versão | Para quê |
| --- | --- | --- |
| `flameshot` | 14.0.0-1 | Screenshot. PrtSc abre `flameshot gui` |
| `xdg-desktop-portal` | 1.22.1-2 | Portal de screenshot. Sem um impl de Access ele não exporta a interface |
| `xdg-desktop-portal-hyprland` | 1.4.1-2 | Captura no Hyprland. Por baixo chama o `grim` |
| `xdg-desktop-portal-gtk` | 1.15.3-1 | Diálogo de permissão (Access). O portal do Hyprland não tem isso |
| `grim` | 1.5.0-2 | Captura que o portal do Hyprland usa. O Flameshot 14 não lê chave de grim no ini |
| `easyeffects` | 8.3.0-1 | Nivelar volume no fone |

`vm-setup.sh` instala flameshot e os três portais. O `grim` e o EasyEffects foram instalados à mão nesta máquina. O `grim` saiu do `vm-setup` de propósito: o ini antigo do Flameshot (`useGrimAdapter`, `disabledGrimWarning`) o binário 14 recusa. O portal do Hyprland continua precisando do `grim` no host.

## Screenshot

**Problema.** No Wayland o compositor não entrega a tela sem portal. Sem o backend GTK o portal 1.22 sobe e não publica Screenshot: o Flameshot espera 30 s e aborta. Com a permissão dada, a captura ainda travava porque o `grim` da tela inteira inclui o `HDMI-A-5`.

**Como ficou.**

- PrtSc, sem modificador, executa `flameshot gui`. Bind em `.config/hypr/hyprland.lua` (live e overlay).
- Window rule `flameshot-multi-display-fix`: classe `flameshot`, monitor `DP-1`, origem `0 0`, tamanho `(monitor_w*1) (monitor_h)`, sem borda, sem arredondamento, flutuante e fixa. O fator é 1 porque só o DP-1 está em 1920×1080. A fórmula `monitor_w*N` da wiki vale para monitores da mesma resolução.
- `HDMI-A-5` desligado no mesmo `hyprland.lua`.
- O live ainda fixa o DP-1 em `1920x1080@144`. O overlay do meta-repo deixa o monitor em `preferred` / `auto` e só desliga o HDMI virtual.
- Não há `~/.config/flameshot/flameshot.ini`. As chaves `disabledGrimWarning` e `useGrimAdapter` são do Flameshot 12.

Depois de instalar o portal GTK, na primeira captura o diálogo pede permissão. Aceitar grava o “yes” em `~/.local/share/flatpak/db/screenshot`.

## Áudio

**Problema.** Trechos baixos e altos demais no fone. O EasyEffects já estava no caminho (Chrome → compressor → autogain → limiter → Fifine), mas a cadeia era quase ganho 1.

O que impedia o nivelamento:

- Autogain com silêncio em −18 dB, igual ao alvo. Abaixo disso o ganho não mexe.
- Compressor com makeup ~0. Só abaixava um pouco o que passava de −20 dB.
- Limiter com *gain boost* ligado, empurrando o som para o teto em vez de só limitar.
- A referência de volume olhava 3 s. Mexer no volume do vídeo mudava o fone na hora e a correção demorava.

**Como ficou.** Saída do EasyEffects: `alsa_output.usb-Fifine_Microphones_Fifine_K690_Microphone_REV1.0-00.analog-stereo`. O HDMI do monitor não recebe esse áudio.

Ordem: compressor → autogain → limiter.

| Efeito | Ajuste |
| --- | --- |
| Compressor | Limiar −30 dB, razão 4:1, ataque 15 ms, release 250 ms, knee −12 dB, makeup +8 dB. Modo downward |
| Autogain | Alvo −18 LUFS, silêncio −50 dB, referência momentary (400 ms), histórico 6 s |
| Limiter | Teto −1,5 dB, lookahead 5 ms, release 20 ms, *gain boost* desligado |

O volume do vídeo entra antes dessa cadeia. Um ruído 20 dB mais baixo (−45 dB contra −25 dB) saiu no fone a −20,8 dB e −21,0 dB. O slider do vídeo, depois de uma fração de segundo, não deve mudar o nível do fone. O volume do sink Fifine (40%) fica depois dos efeitos e continua sendo o volume do fone. Sussurro e grito no mesmo vídeo ainda se distinguem.

Config viva: `~/.config/easyeffects/db/` (`easyeffectsrc`, `compressorrc`, `autogainrc`, `limiterrc`). Não entra no overlay do meta-repo.
