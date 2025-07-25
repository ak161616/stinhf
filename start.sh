#!/bin/sh
# 最终版启动脚本 (V26 - Live Export Mode)
set -e
echo "--- [Launcher V26] Starting..."

DATA_DIR="/app/data"
PUBLIC_DIR="/app/public"
BACKUP_FILE="backup.tar.gz"

# =====================[ 导出模式 ]=====================
if [ "$EXPORT_MODE" = "true" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!             EXPORT MODE ACTIVATED             !!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    
    # 确保 python3 存在，alpine 镜像通常自带
    if ! command -v python3 > /dev/null; then
        echo "--- [Export] python3 not found, attempting to install..."
        apk add --no-cache python3
    fi
    
    echo "--- [Export] Step 1: Compressing data folder ($DATA_DIR)..."
    tar -czvf "/tmp/$BACKUP_FILE" -C "$DATA_DIR" .
    
    echo "--- [Export] Step 2: Moving backup file to public directory ($PUBLIC_DIR)..."
    mv "/tmp/$BACKUP_FILE" "$PUBLIC_DIR/$BACKUP_FILE"
    
    DOWNLOAD_URL="YOUR_SPACE_URL/$BACKUP_FILE"
    echo "--- [Export] Step 3: EXPORT COMPLETE! ---"
    echo "--- Your data is now ready for download. ---"
    
    # 核心修正：不再睡觉，而是启动一个微型文件服务器
    echo "--- Starting temporary download server on port 7860... ---"
    cd "$PUBLIC_DIR"
    exec python3 -m http.server 7860
fi
# ==========================================================

# (正常模式)
echo "$CONFIG_YAML" > /app/config.yaml
cd /app

if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    AUTH_REPO_URL="https://oauth2:${GITHUB_TOKEN}@${REPO_URL}"
    if [ -d "$DATA_DIR/.git" ]; then
        cd "$DATA_DIR"
        git remote set-url origin "$AUTH_REPO_URL"
        git fetch origin main
        git reset --hard origin/main
    else
        rm -rf "$DATA_DIR"
        git clone "$AUTH_REPO_URL" "$DATA_DIR"
    fi
    cd "$DATA_DIR"
    git config user.name "SillyTavern Backup"
    git config user.email "backup@huggingface.space"
    (
        while true; do
            sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
            cd "$DATA_DIR" && git add . > /dev/null
            if ! git diff --cached --quiet; then
                git commit -m "Cloud Backup from HF/${SPACE_ID:-unknown}: $(date)" && git push -f origin HEAD:main
            fi
        done
    ) &
    cd /app
fi

echo "--- [Launcher V26] Starting SillyTavern server..."
exec node server.js
