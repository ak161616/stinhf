#!/bin/sh
# 最终版启动脚本 (V20 - Smart Sync & HF Optimized)
set -e
echo "--- [Launcher V20] Starting..."

# 1. (HF 优化) 直接从环境变量创建 config.yaml
if [ -n "$CONFIG_YAML" ]; then
    echo "$CONFIG_YAML" > /app/config.yaml
    echo "--- [Launcher V20] config.yaml created from environment secret."
else
    echo "CRITICAL: CONFIG_YAML environment variable not found!"
    exit 1
fi

cd /app

# 2. (智能同步) 配置云存档
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "--- [Cloud Save] Initializing Smart Sync..."
    DATA_DIR="/app/data"
    AUTH_REPO_URL="https://oauth2:${GITHUB_TOKEN}@${REPO_URL}"
    
    # 智能判断是克隆 (首次) 还是更新 (重启)
    if [ -d "$DATA_DIR/.git" ]; then
        # 如果是已存在的仓库，则更新
        echo "--- [Cloud Save] Existing data found. Pulling latest changes..."
        cd "$DATA_DIR"
        git remote set-url origin "$AUTH_REPO_URL" # 确保远程地址正确
        git fetch origin main
        git reset --hard origin/main
    else
        # 如果是新目录，则克隆
        echo "--- [Cloud Save] No existing data found. Cloning repository..."
        git clone "$AUTH_REPO_URL" "$DATA_DIR"
    fi
    
    cd "$DATA_DIR"
    git config user.name "SillyTavern Backup"
    git config user.email "backup@huggingface.space"
    echo "--- [Cloud Save] Git user configured locally."

    # 启动后台自动保存
    (
        while true; do
            sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
            cd "$DATA_DIR" && git add . > /dev/null
            if ! git diff --cached --quiet; then
                git commit -m "Cloud Backup: $(date)" && git push -f origin HEAD:main
            fi
        done
    ) &
    echo "--- [Cloud Save] Auto-save process is now running in the background."
    cd /app
fi

echo "--- [Launcher V20] All setup complete. Starting SillyTavern server..."
exec node server.js
