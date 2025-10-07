#!/bin/sh

# 设置 WebDAV 服务的默认端口，用户可以通过环境变量覆盖
WEBDAV_ADDR=${WEBDAV_ADDR:-":8080"}

# --- rclone 配置处理 ---
# 检查环境变量 RCLONE_CONF_BASE64 是否设置
if [ -z "$RCLONE_CONF_BASE64" ]; then
  echo "错误：环境变量 RCLONE_CONF_BASE64 未设置。"
  echo "WebDAV 服务无法启动，因为没有提供任何配置。"
  # 在这种情况下，我们只启动原始应用，让容器至少部分可用
  echo "只启动 cloudflare-imgbed 应用..."
  exec node src/index.js
fi

# 定义 rclone 配置文件路径
# 将其放在 /app 目录下，因为我们没有 root 权限写入 /root/.config
RCLONE_CONFIG_PATH="/app/rclone.conf"

echo "从环境变量生成 rclone 配置文件..."
# 解码 Base64 字符串并写入到配置文件
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

# 检查文件是否成功创建且不为空
if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 数据创建有效的 rclone 配置文件。"
    echo "请检查 RCLONE_CONF_BASE64 变量的内容。"
    exec node src/index.js
fi

echo "rclone 配置文件已成功创建于 ${RCLONE_CONFIG_PATH}"

# --- 启动应用进程 ---

echo "启动 cloudflare-imgbed 应用 (后台)..."
# 再次提醒：请确认基础镜像的实际启动命令并根据需要修改此行
node src/index.js &

echo "启动 rclone WebDAV 服务 (前台)..."
echo "WebDAV 地址: ${WEBDAV_ADDR}"
echo "WebDAV 服务目录: /app"

# 在前台启动 rclone WebDAV 服务
# 使用 --config 参数明确指定配置文件的位置
# 使用 --log-level ERROR 来抑制不必要的日志输出
/app/rclone/rclone serve webdav /app \
  --addr "${WEBDAV_ADDR}" \
  --config "${RCLONE_CONFIG_PATH}" \
  --log-level ERROR