#!/bin/sh
# 最终版启动脚本 (V22 - Fault-Tolerant & Clean Slate)
set -e
echo "--- [Launcher V22] Starting..."

# 1. 从环境变量创建 config.yaml
if [ -n "$CONFIG_YAML" ]; then
    echo "$CONFIG_YAML" > /app/config.yaml
    echo "--- [Launcher V22] config.yaml created from environment secret."
else
    echo "CRITICAL: CONFIG_YAML environment variable not found!"
    exit 1
fi

cd /app

# 2. 配置云存档
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "--- [Cloud Save] Initializing Fault-Tolerant Sync..."
    DATA_DIR="/app/data"
    AUTH_REPO_URL="https://oauth2:${GITHUB_TOKEN}@${REPO_URL}"
    
    if [ -d "$DATA_DIR/.git" ]; then
        echo "--- [Cloud Save] Existing repository found. Pulling latest changes..."
        cd "$DATA_DIR"
        git remote set-url origin "$AUTH_REPO_URL"
        git fetch origin main
        git reset --hard origin/main
    else
        echo "--- [Cloud Save] Directory is not a valid git repository. Forcing a clean clone..."
        rm -rf "$DATA_DIR"
        git clone "$AUTH_REPO_URL" "$DATA_DIR"
    fi
    
    cd "$DATA_DIR"
    git config user.name "SillyTavern Backup"
    git config user.email "backup@huggingface.space"
    echo "--- [Cloud Save] Git user configured locally."

    (
        while true; do
            sleep "$((${AUTOSAVE_INTERVAL:-30} * 60))"
            cd "$DATA_DIR" && git add . > /dev/null
            if ! git diff --cached --quiet; then
                git commit -m "Cloud Backup from HF: $(date)" && git push -f origin HEAD:main
            fi
        done
    ) &
    echo "--- [Cloud Save] Auto-save process is now running in the background."
    cd /app
fi

echo "--- [Launcher V22] All setup complete. Starting SillyTavern server..."
exec node server.js
