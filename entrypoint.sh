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
#nginx
########################################################################################
# 生成 Supervisor 配置文件
cat > ${SUPERVISORD_CONFIG_PATH} << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log

[program:nginx]
command=nginx -g 'daemon off;'  
autorestart=true
user=$(whoami)

[program:alist]
command=su-exec ${PUID}:${PGID} /opt/alist/alist server --no-prefix
autorestart=true
EOF

# 如果设置了 Nezha 相关变量，添加 nezha-agent 到 Supervisor 配置
if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
  cat >> ${SUPERVISORD_CONFIG_PATH} << EOF
[program:nezha-agent]
command=nezha-agent -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_ARGS}
autostart=true
autorestart=true
EOF
else
  echo "NEZHA_SERVER, NEZHA_PORT, 或 NEZHA_KEY 未设置，跳过 nezha-agent 配置。"
fi

########################################################################################
# 修改 /etc/os-release 中的 PLATFORM 和 VERSION，都未设置时跳过
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
# 如果参数是 version，则显示 alist 版本
if [ "$1" = "version" ]; then
  ./alist version
else
  # 启动 Supervisor
  echo "启动 supervisord 以管理服务..."
  exec supervisord -n -c ${SUPERVISORD_CONFIG_PATH}
fi

########################################################################################




