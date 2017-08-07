# alpine-postgre

PostgreSQL Docker container based on Alpine Linux and with the same API as [official container has](https://hub.docker.com/_/postgres/).

Whats different?

  1. Added `POSTGRES_LOG_STATEMENTS` environment variable that helps with settings custom verbosity for statements log.
  2. Added `REPLICATOR_USER` (default: `phhoard`) and `REPLICATOR_PASSWORD` environment variables that will allow replication connections to a running container. (By default PostgreSQL `all` statement does not include `replication` in `pg_hba.conf`.)
  3. Improved entrypoint script to support backups from restored PostgeSQL data directory.

## How to restore from backup?

Place your restored `PGDATA` to `${PGDATA}/../restored_data` (by default: `var/lib/postgresql/restored_data`) and restart the container. During restart it will:

  1. Move current PGDATA to `${PGDATA}/../corrupted_data`. (You will need to remove it manually later.)
  2. Move files from `restored_data` to `$PGDATA`.
  3. Remove `restored_data` directory.
