FROM postgres:9.6.3-alpine
MAINTAINER Nebo#15 <support@nebo15.com>

# Important!  Update this no-op ENV variable when this Dockerfile
# is updated with the current date. It will force refresh of all
# of the base images and things like `apt-get update` won't be using
# old cached versions when the Dockerfile is built.
ENV TERM=xterm \
    HOME=/

WORKDIR /

COPY /docker-entrypoint-initdb.d/ /docker-entrypoint-initdb.d/
COPY docker-entrypoint.sh /usr/local/bin/
