#!/bin/sh
# 最终版启动脚本 (V25 - Export Mode & Fault-Tolerant)
set -e
echo "--- [Launcher V25] Starting..."

DATA_DIR="/app/data"
PUBLIC_DIR="/app/public"
BACKUP_FILE="backup.tar.gz"

# =====================[ 导出模式 ]=====================
if [ "$EXPORT_MODE" = "true" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!             EXPORT MODE ACTIVATED             !!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    
    echo "--- [Export] Step 1: Compressing data folder ($DATA_DIR)..."
    # 使用 tar 命令进行打包压缩
    tar -czvf "/tmp/$BACKUP_FILE" -C "$DATA_DIR" .
    
    echo "--- [Export] Step 2: Moving backup file to public directory ($PUBLIC_DIR)..."
    mv "/tmp/$BACKUP_FILE" "$PUBLIC_DIR/$BACKUP_FILE"
    
    DOWNLOAD_URL="YOUR_SPACE_URL/$BACKUP_FILE"
    echo "--- [Export] Step 3: EXPORT COMPLETE! ---"
    echo "--- Your data is now ready for download. ---"
    echo "--- Please go to the following URL in your browser NOW: ---"
    echo "--- $DOWNLOAD_URL ---"
    echo "(Replace YOUR_SPACE_URL with your actual Hugging Face Space URL)"
    
    echo "--- The container will now sleep indefinitely to keep the download link active. ---"
    # 无限循环等待，保持容器运行
    while true; do sleep 3600; done
    exit 0 # 永远不会执行到这里，但作为好习惯
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

echo "--- [Launcher V25] Starting SillyTavern server..."
exec node server.js
