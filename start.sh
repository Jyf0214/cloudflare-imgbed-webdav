#!/bin/sh

# 确保关键目录存在
mkdir -p /app/data

# --- 配置 ---
if [ -z "$RCLONE_CONF_BASE64" ] || [ -z "$BACKUP_REMOTE_PATH" ]; then
  echo "警告：未提供 RCLONE_CONF_BASE64 或 BACKUP_REMOTE_PATH。" >&2
  echo "自动备份/恢复功能禁用。" >&2
  exec npm run start
fi

RCLONE_CONFIG_PATH="/tmp/rclone.conf"
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 创建有效的 rclone 配置文件。" >&2
    exec npm run start
fi

RCLONE_CMD="/app/rclone/rclone --config ${RCLONE_CONFIG_PATH}"

# --- 1. 启动时恢复 ---
if [ "$(echo "$RESTORE_ON_STARTUP" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  echo "检测到 RESTORE_ON_STARTUP=true，从主备份路径恢复..."
  # 恢复逻辑不变，总是从最新的状态恢复
  $RCLONE_CMD copy -v "${BACKUP_REMOTE_PATH}/data" "/app/data"
  $RCLONE_CMD copyto -v "${BACKUP_REMOTE_PATH}/wrangler.toml" "/app/wrangler.toml"
  echo "恢复操作完成。"
fi

# --- 2. 启动主应用 (后台) ---
echo "在后台启动 cloudflare-imgbed 主应用..."
npm run start &
APP_PID=$!
sleep 5

# --- 3. 启动定期备份 (前台循环) ---
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}
MAX_BACKUPS=${MAX_BACKUPS:-10} # [新增] 设置最大备份版本数，默认为 10
echo "启动定期备份任务，每 ${BACKUP_INTERVAL} 秒一次，保留最多 ${MAX_BACKUPS} 个版本。"

while true; do
  TIMESTAMP=$(date +"%Y-%m-%dT%H-%M-%S")
  echo "====== 开始执行备份 [${TIMESTAMP}] ======"

  # --- 3a. 备份数据 ---
  echo "正在同步最新版本到主备份目录..."
  # 使用 sync --backup-dir，这是 rclone 最强大的版本控制功能
  # 它会自动将任何被修改或删除的文件移动到 --backup-dir 指定的带时间戳的目录中
  $RCLONE_CMD sync -v "/app/data" "${BACKUP_REMOTE_PATH}/data" --backup-dir "${BACKUP_REMOTE_PATH}/versions/data/${TIMESTAMP}"
  echo "正在备份 wrangler.toml..."
  # 对于单个文件，我们先复制旧文件做版本，再上传新文件
  $RCLONE_CMD moveto -v "${BACKUP_REMOTE_PATH}/wrangler.toml" "${BACKUP_REMOTE_PATH}/versions/wrangler.toml/${TIMESTAMP}.toml" --ignore-errors
  $RCLONE_CMD copyto -v "/app/wrangler.toml" "${BACKUP_REMOTE_PATH}/wrangler.toml"

  echo "备份操作完成。"

  # --- 3b. 清理旧版本 ---
  echo "开始检查并清理旧的备份版本..."
  
  # 清理 data 目录的旧版本
  # lsf --dirs-only 列出所有版本目录，sort 排序，head 筛选出最旧的那些
  data_dirs_to_purge=$($RCLONE_CMD lsf -F p --dirs-only "${BACKUP_REMOTE_PATH}/versions/data/" | sort | head -n -$MAX_BACKUPS)
  for dir in $data_dirs_to_purge; do
      echo "清理旧的 data 备份: ${dir}"
      $RCLONE_CMD purge "${BACKUP_REMOTE_PATH}/versions/data/${dir}"
  done

  # 清理 wrangler.toml 的旧版本
  toml_files_to_purge=$($RCLONE_CMD lsf -F p "${BACKUP_REMOTE_PATH}/versions/wrangler.toml/" | sort | head -n -$MAX_BACKUPS)
  for file in $toml_files_to_purge; do
      echo "清理旧的 wrangler.toml 备份: ${file}"
      $RCLONE_CMD deletefile "${BACKUP_REMOTE_PATH}/versions/wrangler.toml/${file}"
  done

  echo "清理完成。将在 ${BACKUP_INTERVAL} 秒后再次执行。"
  echo "=========================================="
  sleep "$BACKUP_INTERVAL"
done

wait $APP_PID