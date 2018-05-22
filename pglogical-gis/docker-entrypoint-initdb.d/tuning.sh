#!/bin/bash
# Increasing max connections limit
set -e

echo "max_connections = 2048" >> "${PGDATA}/postgresql.conf"
echo "shared_buffers = 512MB" >> "${PGDATA}/postgresql.conf"
echo "logging_collector = 'on'" >> "${PGDATA}/postgresql.conf"
echo "log_statement = 'all'" >> "${PGDATA}/postgresql.conf"
echo "log_line_prefix = '%m [%p] [user: %u] [database: %d] [host: %h] '" >> "${PGDATA}/postgresql.conf"
echo "log_filename = '%Y-%m-%d_%H%M%S-${POSTGRES_DB}.log'" >> "${PGDATA}/postgresql.conf"
echo "log_truncate_on_rotation = 'on'" >> "${PGDATA}/postgresql.conf"
echo "log_rotation_age = 60" >> "${PGDATA}/postgresql.conf"
echo "log_rotation_size = 1000000" >> "${PGDATA}/postgresql.conf"

echo "pgaudit.log = 'all'" >> "${PGDATA}/postgresql.conf"
echo "pgaudit.log_level = notice" >> "${PGDATA}/postgresql.conf"
echo "pgaudit.log_parameter = 'on'" >> "${PGDATA}/postgresql.conf"

# Turn off any logging for application user, ${POSTGRES_USER}
# (e.g. by convention, a user called "db", see "postgre-sts.yaml" files in charts)
#
psql -v ON_ERROR_STOP=1 --username "postgres" --dbname "$POSTGRES_DB" <<-EOSQL
  ALTER ROLE ${POSTGRES_USER} SET log_statement = 'none';
  ALTER ROLE ${POSTGRES_USER} SET pgaudit.log = 'none';
EOSQL
