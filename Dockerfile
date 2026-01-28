FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ARG KOHA_VERSION=23.11
ARG TARGETARCH

# initialise dependencies
RUN apt-get update \
    && apt-get install -y \
        curl \
        ca-certificates \
        apt-transport-https \
        apache2 \
        nano \
        postfix \
        mariadb-client \
        gnupg \
        rabbitmq-server \
        memcached \
    && mkdir -p --mode=0755 /etc/apt/keyrings \
    && curl -fsSL https://debian.koha-community.org/koha/gpg.asc -o /etc/apt/keyrings/koha.asc \
    && echo "deb [signed-by=/etc/apt/keyrings/koha.asc] https://debian.koha-community.org/koha ${KOHA_VERSION} main" | tee /etc/apt/sources.list.d/koha.list \
    && apt-get update \
    && apt-get install -y koha-common \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Time
RUN echo "Europe/Berlin" > /etc/timezone

# configure Apache
RUN a2enmod rewrite headers proxy_http cgi \
    && a2dissite 000-default \
    && echo "Listen 8081\nListen 8080" > /etc/apache2/ports.conf \
    && sed -E -i "s#^(export APACHE_LOG_DIR=).*#\1/var/log/koha/apache#g" /etc/apache2/envvars \
    && mkdir -p /var/log/koha/apache \
    && chown -R www-data:www-data /var/log/koha/apache

WORKDIR /docker
COPY koha-sites.conf ./
COPY setup-koha.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/setup-koha.sh

EXPOSE 2100 6001 8080 8081 80

ENTRYPOINT ["/usr/local/bin/setup-koha.sh"]

# start apache and koha service
CMD service apache2 start && tail -F /var/log/koha/apache/error.log