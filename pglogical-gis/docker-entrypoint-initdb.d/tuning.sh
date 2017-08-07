#!/bin/bash
# Increasing max connections limit
set -e

echo "max_connections = 2048" >> "${PGDATA}/postgresql.conf"
echo "shared_buffers = 512MB" >> "${PGDATA}/postgresql.conf"
