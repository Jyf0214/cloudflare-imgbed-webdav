# --- STAGE 1: Builder ---
# 使用一个临时的、小巧的镜像作为构建环境来下载和解压 rclone
FROM alpine:latest as builder

# 安装构建所需的 curl 和 unzip 工具
RUN apk add --no-cache curl unzip

# 设置 rclone 版本和架构
ENV RCLONE_VERSION="v1.66.0"
ENV RCLONE_ARCH="linux-amd64"

WORKDIR /build

# 下载并解压 rclone
RUN curl -O https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    && unzip rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    && mv rclone-${RCLONE_VERSION}-${RCLONE_ARCH} rclone-extracted

# --- STAGE 2: Final Image ---
# 回到您指定的原始镜像
FROM marseventh/cloudflare-imgbed:latest

WORKDIR /app

# [核心步骤] 从第一阶段 (builder) 复制已经解压好的 rclone 文件到最终镜像中
COPY --from=builder /build/rclone-extracted /app/rclone

# --- 配置启动脚本 ---
COPY start.sh /app/start.sh
RUN chmod +x /app/start.sh

# 暴露 WebDAV 服务的端口
EXPOSE 8080

# 设置容器的最终启动命令为我们的脚本
CMD ["/app/start.sh"]