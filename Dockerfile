# --- STAGE 1: Builder ---
FROM alpine:latest as builder

RUN apk add --no-cache curl unzip
ENV RCLONE_VERSION="v1.66.0"
ENV RCLONE_ARCH="linux-amd64"
WORKDIR /build

RUN curl -O https://downloads.rclone.org/${RCLONE_VERSION}/rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    && unzip rclone-${RCLONE_VERSION}-${RCLONE_ARCH}.zip \
    && mv rclone-${RCLONE_VERSION}-${RCLONE_ARCH} rclone-extracted

# --- STAGE 2: Final Image ---
FROM marseventh/cloudflare-imgbed:latest

WORKDIR /app

COPY --from=builder /build/rclone-extracted /app/rclone
COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh

# [CRITICAL FIX] 解决 EACCES 权限问题
# 将 /app 目录及其所有内容的所有权赋予 node 用户 (UID 1000)
# 这必须在所有文件复制完成后、容器启动前执行。
RUN chown -R 1000:1000 /app

CMD ["/app/start.sh"]