FROM alpine:3.5
MAINTAINER Nebo#15 <support@nebo15.com>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2017-04-11 \
    LANG=en_US.UTF-8 \
    TERM=xterm \
    HOME=/

# Configure Postgre version
ENV PG_MAJOR=9.6 \
    PG_VERSION=9.6.2 \
    GOSU_VERSION=1.10 \
    PG_SHA256=0187b5184be1c09034e74e44761505e52357248451b0c854dddec6c231fe50c9

# Setup system environment variables
ENV PATH=/usr/lib/postgresql/$PG_MAJOR/bin:$PATH \
    PGDATA=/var/lib/postgresql/data

# Install gosu
RUN set -ex; \
    apk add --no-cache --virtual .gosu-deps \
        dpkg \
        gnupg \
        openssl && \
    dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" && \
    wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" && \
    wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 && \
    gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu && \
    rm -r "$GNUPGHOME" /usr/local/bin/gosu.asc && \
    chmod +x /usr/local/bin/gosu && \
    gosu nobody true && \
    apk --purge del .gosu-deps

# Create PostgreSQL home dir
RUN set -ex; \
    postgresHome="$(getent passwd postgres)"; \
    postgresHome="$(echo "$postgresHome" | cut -d: -f6)"; \
    [ "$postgresHome" = '/var/lib/postgresql' ]; \
    mkdir -p "$postgresHome"; \
    chown -R postgres:postgres "$postgresHome"

# Install PostgreSQL
RUN set -ex; \
    apk update && \

    # Build deps
    apk add --no-cache --virtual .build-deps \
        bison \
        coreutils \
        gcc \
        libc-dev \
        libedit-dev \
        libxml2-dev \
        libxslt-dev \
        make \
        openssl-dev \
        perl \
        util-linux-dev \
        zlib-dev \
        flex \
        wget \
        ca-certificates && \

    # Fetching sources
    wget ftp://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2 -O /tmp/postgresql-$PG_VERSION.tar.bz2 && \
    tar xvfj /tmp/postgresql-$PG_VERSION.tar.bz2 -C /tmp && \
    cd /tmp/postgresql-$PG_VERSION && \

    # Build sources
    awk '$1 == "#define" && $2 == "DEFAULT_PGSOCKET_DIR" && $3 == "\"/tmp\"" { $3 = "\"/run/postgresql\""; print; next } { print }' src/include/pg_config_manual.h > src/include/pg_config_manual.h.new && \
    grep '/run/postgresql' src/include/pg_config_manual.h.new && \
    mv src/include/pg_config_manual.h.new src/include/pg_config_manual.h && \
    ./configure \
        --enable-integer-datetimes \
        --enable-thread-safety \
        --enable-tap-tests \
        --disable-rpath \
        --with-uuid=e2fs \
        --with-gnu-ld \
        --with-pgport=5432 \
        --with-system-tzdata=/usr/share/zoneinfo \
        --prefix=/usr/local \
        --with-includes=/usr/local/include \
        --with-libraries=/usr/local/lib \
        --with-libedit-preferred \
        --with-openssl \
        --with-libxml \
        --with-libxslt && \
    make -j "$(nproc)" world && \
    make install-world && \
    make -C contrib install && \

    # Get and install runtime deps
    runDeps="$( \
      scanelf --needed --nobanner --recursive /usr/local \
        | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
        | sort -u \
        | xargs -r apk info --installed \
        | sort -u \
    )" && \
    apk add --no-cache --virtual .postgresql-rundeps \
        $runDeps \
        bash \
        tzdata && \
    cd /tmp/postgresql-$PG_VERSION/contrib && \
    make && \
    make install && \
    apk --purge del .build-deps && \
    rm -r /tmp/postgresql-$PG_VERSION* \
          /var/cache/apk/* \
          /usr/local/share/doc \
          /usr/local/share/man

# Performance tuning
RUN echo "net.core.somaxconn = 3072" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_max_syn_backlog = 4096" >> /etc/sysctl.conf && \
    echo "net.ipv4.conf.default.rp_filter = 0" >> /etc/sysctl.conf && \
    echo "fs.file-max = 2097152" >> /etc/sysctl.conf

# Create system folders
RUN mkdir -p /docker-entrypoint-initdb.d && \
    mkdir -p ${PGDATA} && \
    chmod -R 700 ${PGDATA} && \
    mkdir -p /run/postgresql && \
    chmod g+s /run/postgresql && \
    chown -R postgres:postgres /run/postgresql && \
    chown postgres:postgres ${PGDATA}/../ /docker-entrypoint-initdb.d

# Expose data volume
WORKDIR /
VOLUME ${PGDATA}

# Create entypoint scripts
COPY docker-entrypoint.sh /bin/docker-entrypoint.sh
ENTRYPOINT ["/bin/bash", "/bin/docker-entrypoint.sh"]

# Expose Postgre port
EXPOSE 5432

# Run it!
CMD ["postgres"]
