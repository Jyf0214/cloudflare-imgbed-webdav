#!/bin/sh

# --- 配置检查 ---
# 检查 rclone 配置文件和远程路径是否已设置
if [ -z "$RCLONE_CONF_BASE64" ] || [ -z "$BACKUP_REMOTE_PATH" ]; then
  echo "警告：未提供 RCLONE_CONF_BASE64 或 BACKUP_REMOTE_PATH 环境变量。" >&2
  echo "自动备份/恢复功能将被禁用。" >&2
  echo "仅启动 cloudflare-imgbed 主应用..." >&2
  exec npm run start
fi

# [核心] 将配置文件放在 /tmp 目录下
RCLONE_CONFIG_PATH="/tmp/rclone.conf"
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 数据创建有效的 rclone 配置文件。" >&2
    exec npm run start
fi

RCLONE_CMD="/app/rclone/rclone --config ${RCLONE_CONFIG_PATH}"

# --- 1. 启动时恢复 (可选) ---
if [ "$(echo "$RESTORE_ON_STARTUP" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  echo "检测到 RESTORE_ON_STARTUP=true，开始从远程恢复备份..."
  # 为确保目录存在，我们使用 copyto。如果文件不存在，copy 会报错，这可能不是我们想要的。
  # 使用 -v 参数可以查看传输了哪些文件。
  $RCLONE_CMD copy -v "${BACKUP_REMOTE_PATH}/data" "/app/data"
  $RCLONE_CMD copyto -v "${BACKUP_REMOTE_PATH}/wrangler.toml" "/app/wrangler.toml"
  echo "恢复完成。"
else
  echo "跳过启动时恢复。"
fi

# --- 2. 启动主应用 (后台) ---
echo "在后台启动 cloudflare-imgbed 主应用..."
npm run start &
APP_PID=$!

# --- 3. 启动定期备份 (前台循环) ---
# 从环境变量获取备份间隔，默认为3600秒 (1小时)
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}
echo "启动定期备份任务，每 ${BACKUP_INTERVAL} 秒执行一次。"
echo "备份源: /app/data 和 /app/wrangler.toml"
echo "备份目标: ${BACKUP_REMOTE_PATH}"

# 首次执行一次备份，以防启动后立即停止
echo "执行首次备份..."
$RCLONE_CMD copy -v "/app/data" "${BACKUP_REMOTE_PATH}/data"
$RCLONE_CMD copyto -v "/app/wrangler.toml" "${BACKUP_REMOTE_PATH}/wrangler.toml"
echo "首次备份完成。"

# 进入循环
while true; do
  sleep "$BACKUP_INTERVAL"
  echo "执行定期备份..."
  $RCLONE_CMD copy -v "/app/data" "${BACKUP_REMOTE_PATH}/data"
  $RCLONE_CMD copyto -v "/app/wrangler.toml" "${BACKUP_REMOTE_PATH}/wrangler.toml"
  echo "定期备份完成。"
done

# 等待后台的应用进程结束 (理论上循环不会结束)
wait $APP_PID