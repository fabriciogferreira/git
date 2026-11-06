#!/usr/bin/env bash
# Cria DB testing no MySQL do sandbox Olie (phpunit.xml usa DB_DATABASE=testing).
# Problema: RefreshDatabase no Pest falha sem esse schema no MySQL isolado.
set -euo pipefail

mysql --user=root --password="${MYSQL_ROOT_PASSWORD}" <<-EOSQL
    SET GLOBAL log_bin_trust_function_creators = 1;
    CREATE DATABASE IF NOT EXISTS testing;
    CREATE DATABASE IF NOT EXISTS api_main;
    GRANT ALL PRIVILEGES ON \`testing%\`.* TO '${MYSQL_USER}'@'%';
    GRANT ALL PRIVILEGES ON \`api_main%\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
EOSQL
