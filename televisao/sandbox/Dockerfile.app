# Imagem CLI do sandbox Televisão (Pest / mutation / coverage).
# Problema: compose.slim usava php:8.3-cli sem pdo_pgsql/PCOV/git; o card
# exige PHP ≥ 8.4.1 e coverage/mutation precisam de PCOV. Build local no
# meta — não altera Dockerfile.host-api nem a imagem do host-card.
# git: Pest TIA (PEST_TIA_LOCALLY) exige o binário.
FROM php:8.4-cli-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
      $PHPIZE_DEPS \
      git \
      libpq-dev \
      libzip-dev \
      libpng-dev \
      libjpeg62-turbo-dev \
      libfreetype6-dev \
      libicu-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
      pdo_pgsql \
      pgsql \
      intl \
      bcmath \
      zip \
      gd \
      pcntl \
    && pecl install redis pcov \
    && docker-php-ext-enable redis pcov \
    && apt-get purge -y --auto-remove $PHPIZE_DEPS \
    && rm -rf /var/lib/apt/lists/* \
    && php -m | grep -qi pcov \
    && php -m | grep -qi pdo_pgsql \
    && command -v git >/dev/null \
    && php -r 'exit(version_compare(PHP_VERSION, "8.4.0", ">=") ? 0 : 1);'

WORKDIR /work/televisao-api
