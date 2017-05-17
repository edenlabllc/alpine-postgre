#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
  set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
  echo "Changing directories ownerships to 'postgres'.."
  mkdir -p "${PGDATA}"
  chmod 700 "${PGDATA}"
  chown -R postgres "${PGDATA}"

  chmod g+s /run/postgresql
  chown -R postgres /run/postgresql

  # look specifically for PG_VERSION, as it is expected in the DB dir
  if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    eval "gosu postgres initdb ${POSTGRES_INITDB_ARGS}"

    # check password first so we can output the warning before postgres
    # messes it up
    if [ "${POSTGRES_PASSWORD}" ]; then
      pass="PASSWORD '${POSTGRES_PASSWORD}'"
      authMethod=md5
    else
      # The - option suppresses leading tabs but *not* spaces. :)
      cat >&2 <<'EOWARN'
        ****************************************************
        WARNING: No password has been set for the database.
                 This will allow anyone with access to the
                 Postgres port to access your database. In
                 Docker's default configuration, this is
                 effectively any other container on the same
                 system.
                 Use "-e POSTGRES_PASSWORD=password" to set
                 it in "docker run".
        ****************************************************
EOWARN

      pass=
      authMethod=trust
    fi

    # check password first so we can output the warning before postgres
    # messes it up
    if [ "${REPLICATOR_PASSWORD}" ]; then
      repl_pass="PASSWORD '${REPLICATOR_PASSWORD}'"
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
    fi

    { echo; echo "host all all 0.0.0.0/0 ${authMethod}"; } >> "${PGDATA}/pg_hba.conf"

    # internal start of server in order to allow set-up using psql-client
    # does not listen on external TCP/IP and waits until start finishes
    gosu postgres pg_ctl -D "${PGDATA}" \
      -o "-c listen_addresses='localhost'" \
      -w start

    echo "Tuning TCP stack.."
    echo "listen_addresses = '*'" >> "${PGDATA}/postgresql.conf"
    echo "max_connections = 2048" >> "${PGDATA}/postgresql.conf"
    echo "shared_buffers = 512MB" >> "${PGDATA}/postgresql.conf"

    # This will allow pghoard to backup this database
    echo "wal_level = archive" >> "${PGDATA}/postgresql.conf"
    echo "max_wal_senders = 4" >> "${PGDATA}/postgresql.conf"
    echo "max_replication_slots = 4" >> "${PGDATA}/postgresql.conf"

    if [ "${POSTGRES_LOG_STATEMENTS}" ]; then
      echo "log_statement = '${POSTGRES_LOG_STATEMENTS}'" >> "${PGDATA}/postgresql.conf"
    fi

    : ${POSTGRES_USER:=postgres}
    : ${REPLICATOR_USER:=pghoard}
    : ${POSTGRES_DB:=$POSTGRES_USER}
    export POSTGRES_USER POSTGRES_DB REPLICATOR_USER

    psql=( psql -v ON_ERROR_STOP=1 )

    if [ "${POSTGRES_DB}" != "postgres" ]; then
      "${psql[@]}" --username postgres <<-EOSQL
        CREATE DATABASE "${POSTGRES_DB}" ;
EOSQL
      echo
    fi

    op='CREATE'
    if [ "$POSTGRES_USER" = "postgres" ]; then
      op='ALTER'
    fi
    "${psql[@]}" --username postgres <<-EOSQL
      ${op} USER "${POSTGRES_USER}" WITH SUPERUSER ${pass} ;
EOSQL
    echo

    "${psql[@]}" --username postgres <<-EOSQL
      ${op} USER "${REPLICATOR_USER}" ${repl_pass} REPLICATION ;
EOSQL
    echo

    psql+=( --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" )

    echo
    for f in /docker-entrypoint-initdb.d/*; do
      case "$f" in
        *.sh)     echo "$0: running $f"; . "$f" ;;
        *.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
        *.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
        *)        echo "$0: ignoring $f" ;;
      esac
      echo
    done

    gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop

    echo
    echo 'PostgreSQL init process complete; ready for start up.'
    echo
  fi

  exec gosu postgres "$@"
fi

exec "$@"
