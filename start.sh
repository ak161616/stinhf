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
    
    # 核心修正：智能判断并处理所有情况
    if [ -d "$DATA_DIR/.git" ]; then
        # 如果是已存在的仓库，则更新
        echo "--- [Cloud Save] Existing repository found. Pulling latest changes..."
        cd "$DATA_DIR"
        git remote set-url origin "$AUTH_REPO_URL" # 确保远程地址正确
        git fetch origin main
        git reset --hard origin/main
    else
        # 如果目录不是一个有效的 git 仓库 (无论是首次启动还是失败重启)
        # 我们都采取最可靠的策略：强制清理并重新克隆
        echo "--- [Cloud Save] Directory is not a valid git repository. Forcing a clean clone..."
        rm -rf "$DATA_DIR"
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
                git commit -m "Cloud Backup from HF: $(date)" && git push -f origin HEAD:main
            fi
        done
    ) &
    echo "--- [Cloud Save] Auto-save process is now running in the background."
    cd /app
fi

echo "--- [Launcher V22] All setup complete. Starting SillyTavern server..."
exec node server.js
