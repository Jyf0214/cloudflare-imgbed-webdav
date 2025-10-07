#!/bin/sh

# 设置 WebDAV 服务的默认端口，用户可通过环境变量覆盖
WEBDAV_ADDR=${WEBDAV_ADDR:-":8080"}

# 检查环境变量 RCLONE_CONF_BASE64 是否设置
if [ -z "$RCLONE_CONF_BASE64" ]; then
  echo "警告：未提供 RCLONE_CONF_BASE64 环境变量。WebDAV 服务将不会启动。" >&2
  echo "仅启动 cloudflare-imgbed 主应用..." >&2
  # 使用 exec 来让主应用成为主进程，正确处理信号
  exec npm run start
fi

# [核心修改] 将配置文件路径定义在 /tmp 目录下，该目录对任何用户都可写
RCLONE_CONFIG_PATH="/tmp/rclone.conf"

echo "从环境变量生成 rclone 配置文件..."
# 解码 Base64 字符串并写入到 /tmp 下的配置文件
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

# 检查文件是否成功创建且不为空
if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 数据创建有效的 rclone 配置文件。" >&2
    echo "请检查 RCLONE_CONF_BASE64 变量的内容。" >&2
    echo "仅启动 cloudflare-imgbed 主应用..." >&2
    exec npm run start
fi

echo "rclone 配置文件已成功创建于 ${RCLONE_CONFIG_PATH}"

# --- 启动应用进程 ---

echo "启动 cloudflare-imgbed 应用 (后台)..."
# [核心修改] 使用正确的启动命令 'npm run start'
npm run start &

echo "启动 rclone WebDAV 服务 (前台)..."
echo "WebDAV 地址: ${WEBDAV_ADDR}"
echo "WebDAV 服务目录: /app"

# 在前台启动 rclone WebDAV 服务
# 使用 --config 参数明确指定位于 /tmp 的配置文件
# 使用 --log-level ERROR 来抑制不必要的日志输出
/app/rclone/rclone serve webdav /app \
  --addr "${WEBDAV_ADDR}" \
  --config "${RCLONE_CONFIG_PATH}" \
  --log-level ERROR