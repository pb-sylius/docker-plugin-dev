# docker build --pull --tag jaroslavtyc/praguebest-sylius-plugin-dev.8.1:latest . && docker push jaroslavtyc/praguebest-sylius-plugin-dev.8.1:latest

# the different stages of this Dockerfile are meant to be built into separate images
# https://docs.docker.com/compose/compose-file/#target

ARG PHP_VERSION=8.1
ARG ALPINE_VERSION=3.15
ARG COMPOSER_VERSION=latest
ARG PHP_EXTENSION_INSTALLER_VERSION=latest

FROM composer:${COMPOSER_VERSION} AS composer

FROM mlocati/php-extension-installer:${PHP_EXTENSION_INSTALLER_VERSION} AS php_extension_installer

FROM php:${PHP_VERSION}-fpm-alpine${ALPINE_VERSION} AS php_tests

# persistent / runtime deps
RUN apk add --no-cache \
        acl \
        file \
        gettext \
        unzip \
        git \
        autoconf \
        build-base \
        linux-headers \
        mysql-client \
        # to avoid ERROR 1045 (28000): Plugin caching_sha2_password could not be loaded: Error loading shared library /usr/lib/mariadb/plugin/caching_sha2_password.so: No such file or directory
        mariadb-connector-c \
        # shadow adds usermod and groupmod
        shadow \
        sudo \
        bash \
        yarn \
    ;

COPY --from=php_extension_installer /usr/bin/install-php-extensions /usr/local/bin/

# default PHP image extensions
# ctype curl date dom fileinfo filter ftp hash iconv json libxml mbstring mysqlnd openssl pcre PDO pdo_sqlite Phar
# posix readline Reflection session SimpleXML sodium SPL sqlite3 standard tokenizer xml xmlreader xmlwriter zlib
RUN install-php-extensions apcu exif gd intl pdo_mysql opcache zip

RUN pecl channel-update pecl.php.net \
    && pecl install xdebug \
    ;

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY docker/php/test/php.ini        $PHP_INI_DIR/php.ini
COPY docker/php/test/opcache.ini    $PHP_INI_DIR/conf.d/opcache.ini
COPY docker/php/test/xdebug.ini     $PHP_INI_DIR/conf.d/xdebug.ini

COPY docker/php/docker-entrypoint.sh /usr/local/bin/docker-entrypoint
COPY docker/php/docker-change-user-id.sh /usr/local/bin/docker-change-user-id
RUN chmod +x /usr/local/bin/docker-entrypoint

# Composer is not allowed to be run under root / sudo / superuser by default. See docker/php/docker-entrypoint.sh how local user is used.
# https://getcomposer.org/doc/03-cli.md#composer-allow-superuser
# ENV COMPOSER_ALLOW_SUPERUSER=1
ENV PATH="${PATH}:/usr/local/bin"

WORKDIR /srv/sylius

# build for test
ENV APP_ENV=test

ENTRYPOINT ["docker-entrypoint"]
CMD ["php-fpm"]
