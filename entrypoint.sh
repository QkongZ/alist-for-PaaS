#!/bin/bash

export NEZHA_SERVER=${NEZHA_SERVER:-''}
export NEZHA_PORT=${NEZHA_PORT:-''}
export NEZHA_KEY=${NEZHA_KEY:-''}
export NEZHA_ARGS=${NEZHA_ARGS:-'--disable-command-execute --disable-auto-update'}
export platform=${platform:-'Linux'}
export version=${version:-''}

# Supervisor config - Only create if NEZHA variables are set
if [ -n "$NEZHA_SERVER" ] && [ -n "$NEZHA_PORT" ] && [ -n "$NEZHA_KEY" ]; then
  cat > /etc/supervisord.conf << EOF
[supervisord]
nodaemon=true
logfile=/var/log/supervisord.log
[program:agent]
command=nezha-agent -s ${NEZHA_SERVER}:${NEZHA_PORT} -p ${NEZHA_KEY} ${NEZHA_ARGS}
autostart=true
autorestart=true
EOF

  # Start Supervisor
  supervisord -c /etc/supervisord.conf
else
  echo "Skipping supervisor configuration as NEZHA_SERVER, NEZHA_PORT, or NEZHA_KEY is not set."
fi

# Modify platform and version in /etc/os-release
if [ -z "${platform}" ] || [ -z "${version}" ]; then
      platform=$(uname -v)
      version=$(uname -r)

      case "$platform" in
            *debian*|*Debian*) platform="debian" ;;
            *ubuntu*|*Ubuntu*) platform="ubuntu" ;;
            *alpine*|*Alpine*) platform="alpine" ;;
            *) platform="Linux" ;;
      esac

      version=${version%%-*}
fi

sed -i "s/^ID=.*/ID=${platform}/; s/^VERSION_ID=.*/VERSIONversion}/" /etc/os-release


########################################################################################

chown -R ${PUID}:${PGID} /opt/alist/

umask ${UMASK}

nginx

if [ "$1" = "version" ]; then
  ./alist version
else
  exec su-exec ${PUID}:${PGID} ./alist server --no-prefix
fi