# Imagem do app no sandbox Olie (Pest / mutation).
# Problema: olie/api-main não traz PCOV; mutation no Card VM instalava
# pecl no container compartilhado. Build local, sem alterar a imagem do desktop.
# git: Pest TIA (PEST_TIA_LOCALLY) exige o binário — sem commit no api-main.
FROM olie/api-main:latest

USER root
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/* \
    && pecl install pcov \
    && docker-php-ext-enable pcov \
    && php -m | grep -qi pcov \
    && command -v git >/dev/null

USER www-data
WORKDIR /var/www/html
