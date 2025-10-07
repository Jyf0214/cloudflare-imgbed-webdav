# --- STAGE 1: Builder ---
# 使用一个临时的、小巧的镜像作为构建环境
FROM alpine:latest as builder

# 在这个临时环境中，我们可以安装所需的工具
# apk add 是 alpine 系统的包管理器
RUN apk add --no-cache curl unzip

# 设置 rclone 版本和架构
ENV RCLONE_VERSION="v1.66.0"
ENV RCLONE_ARCH="linux-amd64"

# 创建一个工作目录
WORKDIR /build

# 下载并解压 rclone
RUN curl -O https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    && unzip rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    # 将解压后的目录重命名，方便后续引用
    && mv rclone-${RCLONE_VERSION}-${RCLONE_ARCH} rclone-extracted

# --- STAGE 2: Final Image ---
# 现在，回到您指定的原始镜像
FROM marseventh/cloudflare-imgbed:latest

# 设置工作目录
WORKDIR /app

# [核心步骤] 从第一阶段 (builder) 复制已经解压好的 rclone 文件到最终镜像中
# 语法: COPY --from=<stage_name> <source> <destination>
COPY --from=builder /build/rclone-extracted /app/rclone

# --- 剩下的步骤和之前一样 ---

# 复制我们编写的启动脚本到镜像中
COPY start.sh /app/start.sh

# 给予脚本执行权限
RUN chmod +x /app/start.sh

# 暴露 WebDAV 服务的端口
EXPOSE 8080

# 设置容器的启动命令为我们的脚本
CMD ["/app/start.sh"]