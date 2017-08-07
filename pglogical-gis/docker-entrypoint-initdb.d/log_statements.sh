#!/bin/bash
# This script will allow to set custom `log_statement` configuration via `POSTGRES_LOG_STATEMENTS` env
set -e

if [ "${POSTGRES_LOG_STATEMENTS}" ]; then
  echo "log_statement = '${POSTGRES_LOG_STATEMENTS}'" >> "${PGDATA}/postgresql.conf"
fi
