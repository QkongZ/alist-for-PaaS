#!/bin/bash

# 设置默认环境变量
export NEZHA_SERVER=${NEZHA_SERVER:-''}
export NEZHA_PORT=${NEZHA_PORT:-''}
export NEZHA_KEY=${NEZHA_KEY:-''}
export NEZHA_ARGS=${NEZHA_ARGS:-'--disable-command-execute --disable-auto-update'}
export PLATFORM=${PLATFORM:-'Linux'}
export VERSION=${VERSION:-''}

# 配置文件路径
SUPERVISORD_CONFIG_PATH="/etc/supervisord.conf"

########################################################################################
# 设置权限和掩码
chown -R ${PUID}:${PGID} /opt/alist/
umask ${UMASK}

########################################################################################
# 生成 Supervisor 配置文件
cat > ${SUPERVISORD_CONFIG_PATH} << EOF
[supervisord]
nodaemon=true

[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr

[program:alist]
command=/opt/alist/alist server --no-prefix
autostart=true
autorestart=true
user=$(whoami)
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
EOF

# 如果设置了 Nezha 相关变量，添加 nezha-agent 到 Supervisor 配置
if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
  cat >> ${SUPERVISORD_CONFIG_PATH} << EOF
[program:nezha-agent]
command=nezha-agent -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_ARGS}
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
EOF
else
  echo "NEZHA_SERVER, NEZHA_PORT, 或 NEZHA_KEY 未设置，跳过 nezha-agent 配置。"
fi

########################################################################################
# 修改 /etc/os-release 中的 PLATFORM 和 VERSION
if [ -z "${PLATFORM}" ] || [ -z "${VERSION}" ]; then
    PLATFORM=$(uname -v)
    VERSION=$(uname -r)

    case "$PLATFORM" in
        *debian*|*Debian*) PLATFORM="debian" ;;
        *ubuntu*|*Ubuntu*) PLATFORM="ubuntu" ;;
        *alpine*|*Alpine*) PLATFORM="alpine" ;;
        *) PLATFORM="Linux" ;;
    esac

    VERSION=${VERSION%%-*}
fi

sed -i "s/^ID=.*/ID=${PLATFORM}/; s/^VERSION_ID=.*/VERSION_ID=${VERSION}/" /etc/os-release

########################################################################################
# 启动 Supervisor
echo "启动 supervisord 以管理服务..."
supervisord -c ${SUPERVISORD_CONFIG_PATH}

########################################################################################
# 如果参数是 version，则显示 alist 版本
if [ "$1" = "version" ]; then
  ./alist version
else
  exec su-exec ${PUID}:${PGID} ./alist server --no-prefix
fi
