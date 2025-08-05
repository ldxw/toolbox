# ========= 构建阶段 =========
FROM alpine:3.20 AS builder

ARG VERSION=1.9.0
ARG USE_RELEASE_ZIP=false


# 安装构建依赖 + composer
RUN apk add --no-cache \
    php83 \
    php83-phar \
    php83-fpm \
    php83-mbstring \
    php83-json \
    php83-curl \
    php83-iconv \
    php83-pdo \
    php83-pdo_mysql \
    php83-zip \
    php83-session \
    php83-tokenizer \
    php83-fileinfo \
    php83-simplexml \
    php83-dom \
    php83-openssl \
    curl \
    unzip \
    git \
    wget \
    composer \
    bash

WORKDIR /usr/src

# 下载并解压源码（根据变量判断来源）
RUN set -ex && \
    echo "USE_RELEASE_ZIP=$USE_RELEASE_ZIP" && \
    echo "VERSION=$VERSION" && \
    if [ "$USE_RELEASE_ZIP" = "true" ]; then \
      echo "📦 使用 release zip 构建..." && \
      wget -q -c https://github.com/netcccyun/toolbox/releases/download/${VERSION}/toolbox_${VERSION}.zip -O www.zip && \
      unzip www.zip -d www; \
    else \
      echo "🧪 使用 GitHub 源码构建..." && \
      wget -q -c https://github.com/ldxw/toolbox/archive/refs/heads/main.zip -O www.zip && \
      unzip www.zip -d . && \
      mv toolbox-main www && \
      sed -i 's/"1.0.5.2"/"^2.0.0"/' www/composer.json && \
      composer install -d www --no-dev --no-scripts --prefer-dist --no-interaction && \
      test -f www/vendor/autoload.php; \
    fi && \
    rm www.zip

# ========= 运行时阶段 =========
FROM alpine:3.20

WORKDIR /app/www

RUN apk add --no-cache \
    bash \
    curl \
    nginx \
    php83 \
    php83-ctype \
    php83-curl \
    php83-dom \
    php83-fileinfo \
    php83-fpm \
    php83-gd \
    php83-gettext \
    php83-intl \
    php83-iconv \
    php83-mbstring \
    php83-mysqli \
    php83-opcache \
    php83-openssl \
    php83-session \
    php83-simplexml \
    php83-tokenizer \
    php83-xml \
    php83-xmlreader \
    php83-xmlwriter \
    php83-zip \
    php83-pdo \
    php83-pdo_mysql \
    php83-pdo_sqlite \
    supervisor

ENV PHP_INI_DIR=/etc/php83 \
    OVERWRITE=0

# 配置文件
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/fpm-pool.conf /etc/php83/php-fpm.d/www.conf
COPY docker/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY docker/php.ini /etc/php83/conf.d/custom.ini
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# 复制构建产物
COPY --from=builder /usr/src/www /usr/src/www
COPY --from=builder /usr/src/www /app/www

# 清理无用开发文件
RUN rm -rf /usr/src/www/.github \
           /usr/src/www/docker \
           /usr/src/www/Dockerfile \
           /usr/src/www/Dockerfile.local \
           /usr/src/www/entrypoint.sh \
           /app/www/.github \
           /app/www/docker \
           /app/www/Dockerfile \
           /app/www/Dockerfile.local \
           /app/www/entrypoint.sh

# 权限
RUN adduser -D -s /sbin/nologin -g www www && \
    chown -R www:www /app/www /var/lib/nginx /var/log/nginx

# 挂载目录
VOLUME ["/app/www"]

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/sh", "-c", "/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf"]

EXPOSE 80

HEALTHCHECK --interval=10s --timeout=3s --start-period=30s --retries=3 \
  CMD curl --silent --fail http://127.0.0.1/fpm-ping || exit 1
