#!/bin/bash
set -e

# check password first so we can output the warning before postgres
# messes it up
if [ "${REPLICATOR_PASSWORD}" ]; then
  repl_pass="PASSWORD '${REPLICATOR_PASSWORD}'"
  repl_authMethod=md5
else
  # The - option suppresses leading tabs but *not* spaces. :)
  cat >&2 <<'EOWARN'
    ****************************************************
    WARNING: No password has been set for the replicator.
             This will allow anyone with access to the
             Postgres port to access your database. In
             Docker's default configuration, this is
             effectively any other container on the same
             system.
             Use "-e REPLICATOR_PASSWORD=password" to set
             it in "docker run".
    ****************************************************
EOWARN

  repl_pass=
  repl_authMethod=trust
fi

{ echo; echo "host replication all 0.0.0.0/0 ${repl_authMethod}"; } >> "${PGDATA}/pg_hba.conf"

# This will allow pghoard to backup this database
echo "wal_level = 'logical'" >> "${PGDATA}/postgresql.conf"
echo "max_worker_processes = 10" >> "${PGDATA}/postgresql.conf"
echo "max_replication_slots = 10" >> "${PGDATA}/postgresql.conf"
echo "max_wal_senders = 10" >> "${PGDATA}/postgresql.conf"
echo "shared_preload_libraries = 'pglogical'" >> "${PGDATA}/postgresql.conf"
echo "track_commit_timestamp = on" >> "${PGDATA}/postgresql.conf"
echo "host all all 0.0.0.0/0 trust" >>  "${PGDATA}/pg_hba.conf"

: ${REPLICATOR_USER:=pghoard}

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER "${REPLICATOR_USER}" ${repl_pass} REPLICATION ;
EOSQL

export REPLICATOR_USER


