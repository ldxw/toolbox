#!/bin/sh
#
# 首次启动：把镜像里的源码复制到 /app/www（./data 卷），之后升级镜像保留 .env / runtime。
set -e

if [ ! -f /app/www/public/index.php ] || [ ! -f /app/firstrun ]; then
    echo "首次启动：初始化 /app/www"
    cp -a /usr/src/www /app/

    rm -rf /app/www/runtime/* 2>/dev/null || true
    chown -R www:www /app/www

    touch /app/firstrun
fi

# 卷挂载后权限可能被重置，每次都纠正一次（便宜且能省掉一堆 500）
chown -R www:www /app/www/runtime 2>/dev/null || true

exec "$@"
