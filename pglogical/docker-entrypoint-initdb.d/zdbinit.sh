#!/bin/bash
pg_ctl -D "$PGDATA" -m fast -w restart && sleep 15
psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "CREATE EXTENSION pglogical;"
