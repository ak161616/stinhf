#!/bin/sh
# 最终版启动脚本 (V23 - Diagnostic & Fault-Tolerant)
set -e
echo "--- [Launcher V23] Starting..."

# 1. 从环境变量创建 config.yaml
if [ -n "$CONFIG_YAML" ]; then
    echo "$CONFIG_YAML" > /app/config.yaml
    echo "--- [Launcher V23] config.yaml created from environment secret."
else
    echo "CRITICAL: CONFIG_YAML environment variable not found! Halting."
    exit 1
fi

cd /app

# 2. 诊断并配置云存档
echo "--- [Cloud Save] Diagnostic Checks ---"

# 明确检查每一个 Secret
if [ -z "$REPO_URL" ]; then
    echo "--> REPO_URL secret: NOT FOUND. Skipping cloud save."
else
    echo "--> REPO_URL secret: Found."
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "--> GITHUB_TOKEN secret: NOT FOUND. Skipping cloud save."
else
    echo "--> GITHUB_TOKEN secret: Found."
fi

# 只有在所有条件都满足时，才执行
if [ -n "$REPO_URL" ] && [ -n "$GITHUB_TOKEN" ]; then
    echo "--- [Cloud Save] All secrets found. Initializing Smart Sync..."
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
                # 在 commit message 中加入 HF Space 名称，方便区分
                COMMIT_MESSAGE="Cloud Backup from HF/${SPACE_ID:-unknown}: $(date)"
                git commit -m "$COMMIT_MESSAGE" && git push -f origin HEAD:main
            fi
        done
    ) &
    echo "--- [Cloud Save] Auto-save process is now running in the background."
    cd /app
else
    echo "--- [Cloud Save] One or more secrets were missing. Cloud save is DISABLED."
fi

echo "--- [Launcher V23] All setup complete. Starting SillyTavern server..."
exec node server.js
