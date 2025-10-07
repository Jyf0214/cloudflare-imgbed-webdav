#!/bin/sh

# 确保本地关键目录存在
mkdir -p /app/data

# --- 配置检查 ---
if [ -z "$RCLONE_CONF_BASE64" ] || [ -z "$BACKUP_REMOTE_PATH" ]; then
  echo "警告：未提供 RCLONE_CONF_BASE64 或 BACKUP_REMOTE_PATH。自动备份/恢复功能禁用。" >&2
  exec npm run start
fi

RCLONE_CONFIG_PATH="/tmp/rclone.conf"
echo "$RCLONE_CONF_BASE64" | base64 -d > "$RCLONE_CONFIG_PATH"

if [ ! -s "$RCLONE_CONFIG_PATH" ]; then
    echo "错误：无法从 Base64 创建有效的 rclone 配置文件。" >&2
    exec npm run start
fi

RCLONE_CMD="/app/rclone/rclone --config ${RCLONE_CONFIG_PATH}"
# 定义版本存放的根目录
VERSIONS_PATH="${BACKUP_REMOTE_PATH}/versions/data"

# [FIX] 确保远程的版本目录存在，防止后续命令失败
echo "确保远程备份目录 ${VERSIONS_PATH} 存在..."
$RCLONE_CMD mkdir "${VERSIONS_PATH}"

# --- 1. 启动时恢复 ---
if [ "$(echo "$RESTORE_ON_STARTUP" | tr '[:upper:]' '[:lower:]')" = "true" ]; then
  echo "检测到 RESTORE_ON_STARTUP=true，正在查找最新的备份进行恢复..."
  
  # [FIX] 查找远程最新的版本目录
  # lsf 列出目录, sort -r 倒序排序, head -n 1 取第一个 (即最新的)
  LATEST_VERSION_DIR=$($RCLONE_CMD lsf -F p --dirs-only "${VERSIONS_PATH}/" | sort -r | head -n 1)

  if [ -z "$LATEST_VERSION_DIR" ]; then
    echo "未在远程找到任何可用的备份版本。将使用一个空的 data 目录启动。"
  else
    echo "找到最新备份版本: ${LATEST_VERSION_DIR}，开始恢复..."
    # 使用 sync, 效率更高
    $RCLONE_CMD sync -v "${VERSIONS_PATH}/${LATEST_VERSION_DIR}" "/app/data"
    echo "恢复完成。"
  fi
fi

# --- 2. 启动主应用 (后台) ---
echo "在后台启动 cloudflare-imgbed 主应用..."
npm run start &
APP_PID=$!
sleep 5

# --- 3. 启动定期备份 (前台循环) ---
BACKUP_INTERVAL=${BACKUP_INTERVAL:-3600}
MAX_BACKUPS=${MAX_BACKUPS:-10}
echo "启动定期备份任务，每 ${BACKUP_INTERVAL} 秒一次，保留最多 ${MAX_BACKUPS} 个版本。"

while true; do
  TIMESTAMP=$(date +"%Y-%m-%dT%H-%M-%S")
  CURRENT_BACKUP_PATH="${VERSIONS_PATH}/${TIMESTAMP}"
  
  echo "====== 开始备份 [${TIMESTAMP}] 到 ${CURRENT_BACKUP_PATH} ======"
  
  # [FIX] 直接将当前数据完整复制到新的版本目录
  $RCLONE_CMD copy -v "/app/data" "${CURRENT_BACKUP_PATH}"
  echo "备份操作完成。"

  # [FIX] 清理旧版本
  echo "开始检查并清理旧的备份版本..."
  # lsf 列出所有版本目录, sort 排序, head -n -$MAX_BACKUPS 筛选出需要删除的旧目录
  DIRS_TO_PURGE=$($RCLONE_CMD lsf -F p --dirs-only "${VERSIONS_PATH}/" | sort | head -n -$MAX_BACKUPS)
  
  PURGE_COUNT=0
  for dir in $DIRS_TO_PURGE; do
      if [ -n "$dir" ]; then
        echo "清理旧的 data 备份: ${dir}"
        $RCLONE_CMD purge "${VERSIONS_PATH}/${dir}"
        PURGE_COUNT=$((PURGE_COUNT+1))
      fi
  done

  if [ $PURGE_COUNT -eq 0 ]; then
    echo "没有需要清理的旧版本。"
  fi
  
  echo "清理完成。将在 ${BACKUP_INTERVAL} 秒后再次执行。"
  echo "=========================================================="
  sleep "$BACKUP_INTERVAL"
done

wait $APP_PID