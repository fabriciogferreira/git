#!/usr/bin/env bash
# Pré-cria testing_test_1..32 para Pest --parallel.
# Problema: no start, 24 workers batem CREATE DATABASE ao mesmo tempo no
# MySQL do host-card e brigam por lock/metadados; ter os schemas prontos
# (GRANT testing% já cobre) reduz a corrida inicial.
set -euo pipefail

sql=""
i=1
while [ "$i" -le 32 ]; do
    sql="${sql}CREATE DATABASE IF NOT EXISTS \`testing_test_${i}\`;"$'\n'
    i=$((i + 1))
done

mysql --user=root --password="${MYSQL_ROOT_PASSWORD}" <<-EOSQL
${sql}
FLUSH PRIVILEGES;
EOSQL
