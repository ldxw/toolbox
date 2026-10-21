#!/bin/sh
#
# 启动时把镜像里的代码同步到 /app/www（./data 卷），并保留安装状态与运行时数据。
#
# 为什么要同步：镜像更新后如果不同步，卷里跑的还是旧代码，改了 bug 也不会生效。
# 只在「首次启动」和「镜像版本（.docker_revision）变了」时同步，
# 避免每次重启都覆盖后台里改过的模板。
set -e

APP_DIR=/app/www
SRC_DIR=/usr/src/www
REV_FILE=/app/.app_revision

IMG_REV=$(cat "$SRC_DIR/.docker_revision" 2>/dev/null || echo unknown)
CUR_REV=$(cat "$REV_FILE" 2>/dev/null || echo none)

NEED_SYNC=0
if [ ! -f "$APP_DIR/public/index.php" ] || [ ! -f /app/firstrun ]; then
    NEED_SYNC=1
elif [ "$CUR_REV" != "$IMG_REV" ]; then
    NEED_SYNC=1
fi

if [ "$NEED_SYNC" = "1" ]; then
    echo "同步应用代码：${CUR_REV} -> ${IMG_REV}"

    mkdir -p "$APP_DIR"

    # 保留：程序 .env（安装向导生成）、runtime（缓存/会话/上传）、install.lock
    [ -f "$APP_DIR/.env" ] && cp -a "$APP_DIR/.env" /tmp/keep.env 2>/dev/null || true
    [ -f "$APP_DIR/install.lock" ] && cp -a "$APP_DIR/install.lock" /tmp/keep.lock 2>/dev/null || true
    [ -d "$APP_DIR/runtime" ] && mv "$APP_DIR/runtime" /tmp/keep.runtime 2>/dev/null || true

    rm -rf "$APP_DIR"/* "$APP_DIR"/.[!.]* 2>/dev/null || true
    cp -a "$SRC_DIR"/. "$APP_DIR"/

    [ -f /tmp/keep.env ] && cp -a /tmp/keep.env "$APP_DIR/.env" && rm -f /tmp/keep.env || true
    [ -f /tmp/keep.lock ] && cp -a /tmp/keep.lock "$APP_DIR/install.lock" && rm -f /tmp/keep.lock || true

    if [ -d /tmp/keep.runtime ]; then
        rm -rf "$APP_DIR/runtime"
        mv /tmp/keep.runtime "$APP_DIR/runtime"
    fi

    mkdir -p "$APP_DIR/runtime"
    chown -R www:www "$APP_DIR"

    touch /app/firstrun
    echo "$IMG_REV" > "$REV_FILE"
fi

# 卷挂载后 runtime 权限可能被重置，每次纠正一次（便宜且能省掉一堆 500）
chown -R www:www "$APP_DIR/runtime" 2>/dev/null || true

exec "$@"
