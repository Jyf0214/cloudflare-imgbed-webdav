# 使用原始镜像作为基础
FROM marseventh/cloudflare-imgbed:latest

# --- 在非 root 环境下安装 rclone ---

# 设置 rclone 版本和架构
ENV RCLONE_VERSION="v1.66.0"
ENV RCLONE_ARCH="linux-amd64"

# 在工作目录 /app 中进行操作
WORKDIR /app

# 使用 curl 下载 rclone 的预编译二进制文件压缩包，并解压到 /app/rclone 目录
# 这样做不需要 root 权限
RUN set -x \
    && curl -O https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    && unzip rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    # 将解压后的目录重命名为 rclone，方便引用
    && mv rclone-${RCLONE_VERSION}-${RCLONE_ARCH} rclone \
    # 清理下载的压缩包
    && rm rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip

# --- 配置启动脚本 ---

# 复制我们编写的启动脚本到镜像中
COPY start.sh /app/start.sh

# 给予脚本执行权限
RUN chmod +x /app/start.sh

# --- 暴露端口和设置启动命令 ---

# 暴露 WebDAV 服务的端口（默认为 8080）
# 基础镜像应该已经暴露了它自己的应用端口（如 80 或 3000）
EXPOSE 8080

# 设置容器的启动命令为我们的脚本
CMD ["/app/start.sh"]
