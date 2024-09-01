# 使用 alpine:edge 作为构建阶段的基础镜像
FROM alpine:edge as builder
LABEL stage=go-builder
WORKDIR /app/

# 安装必要的软件包
RUN apk add --no-cache bash curl gcc git go musl-dev

# 拉取远程仓库的代码
RUN git clone https://github.com/alist-org/alist.git ./ && ls -la

# 使用 git 克隆下来的 go.mod 和 go.sum 文件
RUN go mod download

# 运行构建脚本
RUN bash build.sh release docker

############################################


# 使用 alpine:edge 作为最终镜像
FROM alpine:edge
USER root

ARG INSTALL_FFMPEG=false
#LABEL MAINTAINER="i@nn.ci"


# 安装必要的软件包
RUN apk update && \
    apk upgrade --no-cache && \
    apk add --no-cache bash ca-certificates su-exec tzdata nginx supervisor && \
    [ "$INSTALL_FFMPEG" = "true" ] && apk add --no-cache ffmpeg; \
    rm -rf /var/cache/apk/* && \
    mkdir -p /run/nginx

# 安装哪吒监控端
RUN LATEST_VERSION=$(curl -s https://api.github.com/repos/nezhahq/agent/releases/latest | jq -r .tag_name) &&\
    wget -O ./nezha-agent.zip "https://github.com/nezhahq/agent/releases/download/${LATEST_VERSION}/nezha-agent_linux_$(uname -m | sed "s#x86_64#amd64#; s#aarch64#arm64#").zip" &&\
    unzip ./nezha-agent.zip &&\
    rm -f ./nezha-agent.zip &&\
    rm -f /etc/alpine-release &&\
    chmod +x ./entrypoint.sh &&\
    chmod +x ./nezha-agent

# 复制 Nginx 配置文件
COPY nginx.conf /etc/nginx/nginx.conf

# 设置工作目录
WORKDIR /opt/alist/

# 从构建阶段复制构建好的二进制文件
COPY --from=builder /app/bin/alist ./
COPY entrypoint.sh /entrypoint.sh
# 设置权限并运行入口脚本
RUN chmod +x /entrypoint.sh && /entrypoint.sh version

# 设置环境变量
ENV PUID=0 PGID=0 UMASK=022

# 定义数据卷和暴露端口
VOLUME /opt/alist/data/
EXPOSE 80

# 设置容器启动命令
CMD [ "/entrypoint.sh" ]
