FROM gliderlabs/alpine:3.4
MAINTAINER Nebo#15 <support@nebo15.com>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV REFRESHED_AT=2016-08-30 \
    LANG=en_US.UTF-8 \
    TERM=xterm \
    POSTGRES_SYS_USER=postgres \
    HOME=/

# Configure Postgre version
ENV PG_MAJOR=9.6 \
    PG_VERSION=9.6.1 \
    GOSU_VERSION=1.10

# Setup system environment variables
ENV PATH=/usr/lib/postgresql/$PG_MAJOR/bin:$PATH \
    PGDATA=/var/lib/postgresql/data

# Install gosu
RUN set -x && \
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

# Install PostgreSQL
RUN apk update && \
    apk add --no-cache build-base \
        readline-dev \
        openssl-dev \
        zlib-dev \
        libxml2-dev \
        glib-lang \
        wget \
        gnupg \
        ca-certificates && \
    wget ftp://ftp.postgresql.org/pub/source/v$PG_VERSION/postgresql-$PG_VERSION.tar.bz2 -O /tmp/postgresql-$PG_VERSION.tar.bz2 && \
    tar xvfj /tmp/postgresql-$PG_VERSION.tar.bz2 -C /tmp && \
    cd /tmp/postgresql-$PG_VERSION && \
    ./configure --enable-integer-datetimes --enable-thread-safety --prefix=/usr/local --with-libedit-preferred --with-openssl && \
    make world && \
    make install world && \
    make -C contrib install && \
    cd /tmp/postgresql-$PG_VERSION/contrib && \
    make && \
    make install && \
    apk --purge del build-base openssl-dev zlib-dev libxml2-dev wget gnupg ca-certificates && \
    rm -r /tmp/postgresql-$PG_VERSION* /var/cache/apk/*

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
    chown ${POSTGRES_SYS_USER}: ${PGDATA}/../ /docker-entrypoint-initdb.d

RUN apk add --update --no-cache bash

# Expose data volume
WORKDIR /
VOLUME ${PGDATA}

# Create entypoint scripts
COPY docker-entrypoint.sh /bin/docker-entrypoint.sh
ENTRYPOINT [ "/bin/bash", "/bin/docker-entrypoint.sh" ]

# Expose Postgre port
EXPOSE 5432

# Run it!
CMD ["postgres"]
