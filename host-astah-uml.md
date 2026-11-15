# Astah UML 12 no host (Distrobox)

O host é Omarchy (Arch). O Astah UML 12 distribui um `.deb` e exige **Adoptium Temurin 25.0.3 ou posterior**; JDK 26 ou mais novo o próprio pacote recusa. O `.deb` não instala no Arch. Um container Debian 13 no Distrobox, com Podman rootless, deixa o atalho e o comando `astah-uml` nesta sessão. O Docker que já está no host segue para as WorkVMs: esta sessão não está no grupo `docker`, e o app gráfico precisa do Wayland e do X11 do usuário.

Runbook do que foi feito em 2026-11-13. Repetir a partir daqui se o container sumir.

## O que ficou

| Peça | Valor |
| --- | --- |
| Host | `distrobox` 1.8.2.5-1, `podman` 6.1.4-1 |
| Container | nome `astah-uml`, imagem `docker.io/library/debian:13` (trixie) |
| Java | Temurin **25.0.3+9** (LTS, 2026-04-21) em `/usr/lib/jvm/jdk-25.0.3+9`, symlink `/usr/lib/jvm/temurin-25` |
| Pacote | `astah-uml` 12.0.0.4fa570.0 (`astah-uml_12.0.0.4fa570-0_all.deb`) |
| Comando no host | `~/.local/bin/astah-uml` (o `PATH` de login já inclui `~/.local/bin`) |
| Atalho | `~/.local/share/applications/astah-uml-astah_uml.desktop`, nome **astah\* UML** |
| Ícone | `~/.local/share/icons/astah_uml.png` |
| Dados | `~/.astah/` no home do host (o Distrobox monta o mesmo `$HOME`) |

A janela abre com título `Astah (Evaluation)` e classe `JP-co-esm-caddies-jomt-Jude`. Sem chave de licença o produto entra em avaliação; isso é o estado normal depois desta instalação.

Há um segundo atalho, **Astah-uml**, criado pelo Distrobox. Esse abre um terminal dentro do container (`distrobox enter astah-uml`). O modelador é o **astah\* UML**.

## Downloads

Arquitetura do host: `x86_64`. O manual pede `file /sbin/init`; aqui basta `uname -m`.

Java, tarball oficial do Temurin 25.0.3+9:

```text
https://github.com/adoptium/temurin25-binaries/releases/download/jdk-25.0.3%2B9/OpenJDK25U-jdk_x64_linux_hotspot_25.0.3_9.tar.gz
```

O diretório dentro do tar é `jdk-25.0.3+9`. O Temurin 25 não traz `javaws` (Java Web Start saiu do JDK). O passo de `update-alternatives` para `javaws` do manual antigo não se aplica.

Astah UML 12.0.0, página de membro e o arquivo. O link de membro redireciona para o CDN:

```text
https://members.change-vision.com/old/files/astah_UML/12_0_0
https://cdn.change-vision.com/files/astah-uml_12.0.0.4fa570-0_all.deb
```

Tamanho esperado do `.deb`: 161019236 bytes. O pacote é `Architecture: all` e só **recomenda** `sun-java6-jdk | sun-java6-jre`. O Java usado é o Temurin, não esse recomendado.

## Host

```bash
sudo pacman -S --needed distrobox podman
distrobox create --name astah-uml --image docker.io/library/debian:13 --yes
```

O usuário desta máquina já tem faixa em `/etc/subuid` e `/etc/subgid` (`fabricio:100000:65536`). Sem isso o Podman rootless não sobe.

## Dentro do container

`/tmp` do host aparece no container. Os arquivos abaixo estavam em `/tmp/astah-uml-install/`.

```bash
distrobox enter astah-uml
```

Bibliotecas que o AWT/Swing precisa para abrir janela (nomes do Debian 13, com o sufixo `t64`):

```bash
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
  ca-certificates tar \
  libxrender1 libxtst6 libxi6 libxext6 libx11-6 libxrandr2 \
  libxcursor1 libxinerama1 libxxf86vm1 \
  libgl1 fontconfig fonts-dejavu-core \
  libgtk-3-0t64 libasound2t64
```

JDK, no lugar que o manual descreve (`/usr/lib/jvm`), com o nome desta versão:

```bash
sudo mkdir -p /usr/lib/jvm
sudo tar -C /usr/lib/jvm -xzf /tmp/astah-uml-install/OpenJDK25U-jdk_x64_linux_hotspot_25.0.3_9.tar.gz
sudo ln -sfn /usr/lib/jvm/jdk-25.0.3+9 /usr/lib/jvm/temurin-25
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/temurin-25/bin/java 2500
sudo update-alternatives --install /usr/bin/javac javac /usr/lib/jvm/temurin-25/bin/javac 2500
sudo update-alternatives --set java /usr/lib/jvm/temurin-25/bin/java
sudo update-alternatives --set javac /usr/lib/jvm/temurin-25/bin/javac
java -version
```

A saída tem de ser `OpenJDK Runtime Environment Temurin-25.0.3+9 (build 25.0.3+9-LTS)`.

O `preinst` do `.deb` mostra a licença e lê `yes` no terminal. Com stdin fechado a resposta vazia conta como `no` e o `dpkg` aborta. `DEBIAN_FRONTEND=passthrough` pula esse prompt (é o único valor que o script trata assim):

```bash
sudo DEBIAN_FRONTEND=passthrough dpkg -i /tmp/astah-uml-install/astah-uml_12.0.0.4fa570-0_all.deb
```

O `postinst` pode imprimir “Please install Adoptium Temurin 25.0.3 or later” mesmo com o Temurin certo. O script grava `VERSION=21.0` e procura a string `21.0` no caminho de `/usr/bin/java`. O caminho real é `.../jdk-25.0.3+9/bin/java`, então o teste falha e a mensagem sai. A instalação em si conclui. Conferir com `java -version`, não com esse aviso.

`/usr/bin/astah-uml` é symlink de `/usr/lib/astah_uml/astah-uml`. O script chama `java` do `PATH`. Logo depois do `#!/bin/sh` ficam duas linhas: o Temurin no `PATH`, e o flag que faz o Swing pintar no Hyprland. Um `dpkg -i` de novo regride o script; reaplicar as duas.

```sh
#!/bin/sh
PATH=/usr/lib/jvm/temurin-25/bin:${PATH}
export _JAVA_AWT_WM_NONREPARENTING=1
```

```bash
sudo sed -i '2i PATH=/usr/lib/jvm/temurin-25/bin:${PATH}\nexport _JAVA_AWT_WM_NONREPARENTING=1' /usr/lib/astah_uml/astah-uml
```

Sem `_JAVA_AWT_WM_NONREPARENTING=1` a janela abre e fica branca. O Hyprland não reparenta a janela; o AWT espera esse evento para o primeiro paint e o Swing não desenha menu nem barra. Uma janela Java mínima, com fundo vermelho, saiu cinza sem o flag e vermelha com ele. O Astah com o flag mostra File, Edit, Diagram e a barra de ferramentas. A área do diagrama continua branca enquanto não houver diagrama aberto.

## Exportar para o host

Ainda dentro do container:

```bash
distrobox-export --app /usr/share/applications/astah_uml.desktop --export-label none
distrobox-export --bin /usr/bin/astah-uml --export-path "$HOME/.local/bin"
```

O `.desktop` exportado aponta `Icon=astah_uml.png`. O arquivo copiado fica em `~/.local/share/icons/astah_uml.png`, fora da árvore `hicolor`, e o launcher pode não achar o ícone. Nesta máquina o `Icon=` do atalho foi trocado para o caminho absoluto:

```text
Icon=/home/fabricio/.local/share/icons/astah_uml.png
```

Um `distrobox-export` de novo reescreve o `.desktop` e perde essa linha.

## Abrir

No menu: **astah\* UML**.

No terminal:

```bash
astah-uml
```

Os dois passam por `distrobox enter -n astah-uml -- astah-uml`. O container sobe se estiver parado. Diagramas e a configuração ficam em `~/.astah/` no home do host.

Entrar no Debian para manutenção:

```bash
distrobox enter astah-uml
```

## Remover

```bash
distrobox enter astah-uml -- distrobox-export --delete --app /usr/share/applications/astah_uml.desktop
distrobox enter astah-uml -- distrobox-export --delete --bin /usr/bin/astah-uml --export-path "$HOME/.local/bin"
distrobox rm astah-uml
```

`~/.astah/` permanece. `distrobox` e `podman` no host também, se mais nada depender deles.
