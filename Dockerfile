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

# [修改] 不再需要暴露 WebDAV 端口
# EXPOSE 8080

CMD ["/app/start.sh"]