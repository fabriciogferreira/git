#!/usr/bin/env bash
# Espelho mínimo do docker-workspace/mysql/create-testing-database.sh
# (+ log_bin_trust). Databases por card entram no ensure (provision).

mysql --user=root --password="$MYSQL_ROOT_PASSWORD" <<-EOSQL
    SET GLOBAL log_bin_trust_function_creators = 1;
EOSQL

mysql --user=root --password="$MYSQL_ROOT_PASSWORD" <<-EOSQL
    CREATE DATABASE IF NOT EXISTS testing;
    GRANT ALL PRIVILEGES ON \`testing%\`.* TO '$MYSQL_USER'@'%';
    FLUSH PRIVILEGES;
EOSQL
