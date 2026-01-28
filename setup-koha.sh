#!/bin/bash
set -x

# ensure that .env is load in (via Docker-Compose!)
# check dependend variables
: "${KOHA_INSTANCE:?KOHA_INSTANCE is not set}"
: "${MYSQL_USER:?MYSQL_USER is not set}"
: "${MYSQL_PASSWORD:?MYSQL_PASSWORD is not set}"
: "${DB_NAME:?DB_NAME is not set}"
: "${MYSQL_SERVER:?MYSQL_SERVER is not set}"

# set defaults, if they not set bevore
KOHA_INTRANET_PORT="${KOHA_INTRANET_PORT:-8081}"
KOHA_OPAC_PORT="${KOHA_OPAC_PORT:-8080}"
MEMCACHED_SERVERS="${MEMCACHED_SERVERS:-memcached:11211}"
ZEBRA_MARC_FORMAT="${ZEBRA_MARC_FORMAT:-marc21}"
KOHA_LANGS="${KOHA_LANGS:-en}"
USE_ELASTICSEARCH="${USE_ELASTICSEARCH:-false}"

# replace variables in koha-sites.conf
envsubst < /docker/koha-sites.conf > /etc/koha/koha-sites.conf
echo "ServerName localhost" >> /etc/apache2/apache2.conf

# configure apache2 opac on port 80
echo "Listen 80" >> /etc/apache2/ports.conf

# Healthcheck: wait until the database is ready
until mysqladmin ping -h "${MYSQL_SERVER}" -u "${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; do
    echo "wait for the database..."
    sleep 3
done

# create /etc/koha/passwd entry
echo -n "${KOHA_INSTANCE}:${MYSQL_USER}:${MYSQL_PASSWORD}:${DB_NAME}:${MYSQL_SERVER}" > /etc/koha/passwd

source /usr/share/koha/bin/koha-functions.sh

# Elasticsearch-Parameters
ES_PARAMS=""
if [[ "${USE_ELASTICSEARCH}" == "true" ]]; then
    ES_PARAMS="--elasticsearch-server ${ELASTICSEARCH_HOST}"
fi

# create koha instanz (only if they not is present already)
if ! is_instance "${KOHA_INSTANCE}" || [ ! -f "/etc/koha/sites/${KOHA_INSTANCE}/koha-conf.xml" ]; then
    echo "create Koha-Instanz ${KOHA_INSTANCE}"
    koha-create ${ES_PARAMS} --use-db "${KOHA_INSTANCE}" || true
else
    echo "Instanz ${KOHA_INSTANCE} exists already – inizialise directorys"
    koha-create-dirs "${KOHA_INSTANCE}"
fi

# reindex Elasticsearch
if [[ "${USE_ELASTICSEARCH}" == "true" ]]; then
    koha-elasticsearch --rebuild -p "$(nproc)" "${KOHA_INSTANCE}" &
fi

# language
INSTALLED_LANGS=$(koha-translate -l)

# remove unwished languages
for lang in $INSTALLED_LANGS; do
    if ! echo "$KOHA_LANGS" | grep -qw "$lang"; then
        echo "remove language $lang"
        koha-translate -r "$lang"
    fi
done

# install language
for lang in $KOHA_LANGS; do
    if ! echo "$INSTALLED_LANGS" | grep -qw "$lang"; then
        echo "initialise language $lang"
        koha-translate -i "$lang"
    else
        echo "Language $lang is already initialise"
    fi
done

# Prepare Log-directorys
mkdir -p "/var/log/koha/${KOHA_INSTANCE}"
touch "/var/log/koha/${KOHA_INSTANCE}/opac-error.log" "/var/log/koha/${KOHA_INSTANCE}/intranet-error.log"
chown -R "${KOHA_INSTANCE}-koha:${KOHA_INSTANCE}-koha" "/var/log/koha/${KOHA_INSTANCE}"

# plack-proxy
koha-plack --enable "${KOHA_INSTANCE}"
koha-plack --start "${KOHA_INSTANCE}"
tail -F /var/lib/init.d/

# activate services
service memcached start
service apache2 start
service rabbitmq-server start

# logs
touch /var/log/koha/apache/error.log
tail -F /var/log/koha/${KOHA_INSTANCE}/opac-error.log \
       /var/log/koha/${KOHA_INSTANCE}/intranet-error.log \
       /var/log/koha/apache/error.log
