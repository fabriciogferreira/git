# Imagem do app no sandbox Olie (Pest / mutation).
# Problema: olie/api-main não traz PCOV; mutation no Card VM instalava
# pecl no container compartilhado. Build local, sem alterar a imagem do desktop.
FROM olie/api-main:latest

USER root
RUN pecl install pcov \
    && docker-php-ext-enable pcov \
    && php -m | grep -qi pcov

USER www-data
WORKDIR /var/www/html
