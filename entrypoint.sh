#!/bin/bash

set -e

#if [ ! -f /app/www/public/index.php ] || [ ! -f /app/firstrun ]; then
#    echo 'Copying new files'
#    \cp -a /usr/src/www /app/

#    if [ -d /app/www/runtime/cache ]; then
#        rm -rf /app/www/runtime/*
#    fi

#    chown -R www.www /app/www

#    touch /app/firstrun
#fi

# 默认不覆盖 /app/www（如果已存在）
OVERWRITE=${OVERWRITE:-0}

# 检查目录是否存在且不为空
is_www_empty() {
    # 目录不存在视为"空"状态
    if [ ! -d "/app/www" ]; then
        return 0
    fi
    
    # 检查目录内是否有文件或子目录（排除.和..）
    local file_count
    file_count=$(find /app/www -mindepth 1 -maxdepth 1 | wc -l)
    
    # 0个文件/目录视为空
    [ "$file_count" -eq 0 ]
}

if [ "$OVERWRITE" = "1" ]; then
    echo "📝 覆盖模式启用，强制复制 /usr/src/www 到 /app/www"
    cp -a /usr/src/www /app/
    # 清理缓存
    if [ -d /app/www/runtime/cache ]; then
        rm -rf /app/www/runtime/*
    fi
    # 设置权限
    chown -R www.www /app/www
else
    # 仅检查目录是否为空
    if is_www_empty; then
        echo '📁 目录为空，复制默认文件'
        cp -a /usr/src/www /app/
        # 清理缓存
        if [ -d /app/www/runtime/cache ]; then
            rm -rf /app/www/runtime/*
        fi
        # 设置权限
        chown -R www.www /app/www
    else
        echo '✅ 目录已存在内容，跳过默认文件复制'
    fi
fi

exec "$@"