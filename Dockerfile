# syntax=docker/dockerfile:1
#
# 在线工具箱（ThinkPHP 8 + Nginx + PHP-FPM）
#
# 说明：
#   - 运行时用 alpine + nginx + php83-fpm + supervisor 单容器跑，对外只暴露 80。
#   - 源码来自构建上下文（当前分支），不吃远端 main.zip，保证镜像版本 = 代码版本。
#   - 首次启动时由 entrypoint 把 /usr/src/www 复制到 /app/www，这样 ./data 卷可以在
#     容器重建后继续保留 .env、runtime 缓存和用户上传，不必重新安装。

ARG ALPINE_VERSION=3.22
FROM alpine:${ALPINE_VERSION}

WORKDIR /app/www

# 运行依赖：nginx、php83 及项目要求的扩展（curl / gd / mbstring / openssl / zip / pdo_mysql / iconv / fileinfo）
RUN apk add --no-cache \
        bash \
        curl \
        tzdata \
        nginx \
        supervisor \
        php83 \
        php83-ctype \
        php83-curl \
        php83-dom \
        php83-fileinfo \
        php83-fpm \
        php83-gd \
        php83-gettext \
        php83-iconv \
        php83-intl \
        php83-mbstring \
        php83-mysqli \
        php83-opcache \
        php83-openssl \
        php83-phar \
        php83-pdo \
        php83-pdo_mysql \
        php83-session \
        php83-simplexml \
        php83-sodium \
        php83-tokenizer \
        php83-xml \
        php83-xmlreader \
        php83-xmlwriter \
        php83-zip \
    && ln -sf /usr/bin/php83 /usr/bin/php \
    && rm -rf /var/cache/apk/* /tmp/*

# nginx / php-fpm / supervisord 配置
COPY docker/nginx.conf /etc/nginx/nginx.conf
ENV PHP_INI_DIR=/etc/php83
COPY docker/fpm-pool.conf ${PHP_INI_DIR}/php-fpm.d/www.conf
COPY docker/php.ini ${PHP_INI_DIR}/conf.d/custom.ini
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# 应用源码（构建上下文 = 仓库根目录）
COPY . /usr/src/www

# 安装依赖 + 装好后清掉不需要进运行时的东西
RUN set -eux; \
    cd /usr/src/www; \
    composer install --no-interaction --no-dev --optimize-autoloader --no-cache --no-scripts || \
    composer install --no-interaction --no-dev --optimize-autoloader --no-cache; \
    php think service:discover >/dev/null 2>&1 || true; \
    php think vendor:publish >/dev/null 2>&1 || true; \
    rm -rf /usr/src/www/.git /usr/src/www/.github /usr/src/www/.travis.yml; \
    mkdir -p /usr/src/www/runtime; \
    rm -rf /usr/src/www/runtime/*; \
    adduser -D -s /sbin/nologin -g www www; \
    mkdir -p /app; \
    chown -R www:www /usr/src/www /app /var/lib/nginx /var/log/nginx

COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 80

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
