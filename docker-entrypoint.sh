#!/bin/bash
set -e

if [ "${1:0:1}" = '-' ]; then
  set -- ${POSTGRES_SYS_USER} "$@"
fi

if [ "$1" = 'postgres' ]; then
  echo "Changing directories ownerships to '${POSTGRES_SYS_USER}'.."
  mkdir -p "${PGDATA}"
  chmod 700 "${PGDATA}"
  chown -R ${POSTGRES_SYS_USER} "${PGDATA}"

  chmod g+s /run/postgresql
  chown -R ${POSTGRES_SYS_USER} /run/postgresql

  # look specifically for PG_VERSION, as it is expected in the DB dir
  if [ ! -s "${PGDATA}/PG_VERSION" ]; then
    eval "gosu ${POSTGRES_SYS_USER} initdb ${POSTGRES_INITDB_ARGS}"

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

    { echo; echo "host all all 0.0.0.0/0 ${authMethod}"; } >> "${PGDATA}/pg_hba.conf"

    # internal start of server in order to allow set-up using psql-client
    # does not listen on external TCP/IP and waits until start finishes
    gosu ${POSTGRES_SYS_USER} pg_ctl -D "${PGDATA}" \
      -o "-c listen_addresses='localhost'" \
      -w start

    echo "Tuning TCP stack.."
    echo "listen_addresses = '*'" >> "${PGDATA}/postgresql.conf"
    echo "max_connections = 2048" >> "${PGDATA}/postgresql.conf"
    echo "shared_buffers = 512MB" >> "${PGDATA}/postgresql.conf"

    : ${POSTGRES_USER:=$POSTGRES_SYS_USER}
    : ${POSTGRES_DB:=$POSTGRES_USER}
    export POSTGRES_USER POSTGRES_DB

    psql=( psql -v ON_ERROR_STOP=1 )

    if [ "${POSTGRES_DB}" != "${POSTGRES_SYS_USER}" ]; then
      "${psql[@]}" --username ${POSTGRES_SYS_USER} <<-EOSQL
        CREATE DATABASE "${POSTGRES_DB}" ;
EOSQL
      echo
    fi

    op='CREATE'
    if [ "$POSTGRES_USER" = "${POSTGRES_SYS_USER}" ]; then
      op='ALTER'
    fi
    "${psql[@]}" --username ${POSTGRES_SYS_USER} <<-EOSQL
      ${op} USER "${POSTGRES_USER}" WITH SUPERUSER ${pass} ;
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

    gosu ${POSTGRES_SYS_USER} pg_ctl -D "$PGDATA" -m fast -w stop

    echo
    echo 'PostgreSQL init process complete; ready for start up.'
    echo
  fi

  exec gosu postgres "$@"
fi

exec "$@"
