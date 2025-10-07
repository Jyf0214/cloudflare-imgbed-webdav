#!/bin/sh

# [FIX] 脚本开始时就确保关键目录存在，防止后续操作因目录不存在而失败
mkdir -p /app/data

# --- 配置检查 ---
if [ -z "$RCLONE_CONF_BASE64" ] || [ -z "$BACKUP_REMOTE_PATH" ]; then
  echo "警告：未提供 RCLONE_CONF_BASE64 或 BACKUP_REMOTE_PATH 环境变量。" >&2
  echo "自动备份/恢复功能将被禁用。" >&2
  exec npm run start
fi

RCLONE_CONFIG_PATH="/tmp/rclone.conf"
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 数据创建有效的 rclone 配置文件。" >&2
    exec npm run start
fi

RCLONE_CMD="/app/rclone/rclone --config ${RCLONE_CONFIG_PATH}"

# --- 1. 启动时恢复 (可选且更健壮) ---
if [ "$(echo "$RESTORE_ON_STARTUP" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  echo "检测到 RESTORE_ON_STARTUP=true，尝试从远程恢复备份..."
  # [FIX] 使用 --ignore-non-existing 来避免在源文件不存在时报错
  # 这对于第一次启动时的“冷启动”场景至关重要
  $RCLONE_CMD copy -v --ignore-non-existing "${BACKUP_REMOTE_PATH}/data" "/app/data"
  $RCLONE_CMD copyto -v --ignore-non-existing "${BACKUP_REMOTE_PATH}/wrangler.toml" "/app/wrangler.toml"
  echo "恢复操作完成。如果没有文件传输，说明远程备份尚不存在，这是正常的。"
else
  echo "跳过启动时恢复。"
fi

# --- 2. 启动主应用 (后台) ---
echo "在后台启动 cloudflare-imgbed 主应用..."
npm run start &
APP_PID=$!

# 等待几秒钟，确保主应用有时间初始化
sleep 5

# --- 3. 启动定期备份 (前台循环) ---
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}
echo "启动定期备份任务，每 ${BACKUP_INTERVAL} 秒执行一次。"

# 循环备份
while true; do
  echo "执行备份..."
  # 使用 sync 命令可以更高效地只同步更改的文件
  $RCLONE_CMD sync -v "/app/data" "${BACKUP_REMOTE_PATH}/data"
  $RCLONE_CMD copyto -v "/app/wrangler.toml" "${BACKUP_REMOTE_PATH}/wrangler.toml"
  echo "备份完成。将在 ${BACKUP_INTERVAL} 秒后再次执行。"
  sleep "$BACKUP_INTERVAL"
done

wait $APP_PID