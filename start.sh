#!/bin/sh

# 设置 rclone WebDAV 服务的默认端口和认证信息
# 用户可以通过环境变量覆盖这些值
WEBDAV_ADDR=${WEBDAV_ADDR:-":8080"}
WEBDAV_USER=${WEBDAV_USER:-"user"}
WEBDAV_PASS=${WEBDAV_PASS:-"pass"}

echo "Starting cloudflare-imgbed application..."
# 启动原始的 cloudflare-imgbed 应用。
# 注意：你需要确认基础镜像的启动命令。这里我们假设是 'node src/index.js'。
# 如果不正确，请根据基础镜像的实际情况修改此行。
# 使用 '&' 将其放入后台运行。
node src/index.js &

# 记录后台进程的PID
APP_PID=$!

echo "Starting rclone WebDAV server..."
echo "WebDAV Address: ${WEBDAV_ADDR}"
echo "WebDAV User: ${WEBDAV_USER}"
echo "WebDAV serving directory: /app"

# 在前台启动 rclone WebDAV 服务
# --addr: 监听地址和端口
# --user/--pass: WebDAV 的用户名和密码
# --log-level ERROR: 将日志级别设为 ERROR，以避免输出不必要的（或被禁止的）信息
# /app: 指定要服务的根目录
/app/rclone/rclone serve webdav /app --addr "${WEBDAV_ADDR}" --user "${WEBDAV_USER}" --pass "${WEBDAV_PASS}" --log-level ERROR

# 等待后台的应用进程结束（虽然在前台进程结束前通常不会执行到这里）
wait $APP_PID
