#rename sample-config.sh to config.sh after editing
#!/bin/bash
set -euo pipefail

# Load .env
ENV_FILE="../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env not found at $ENV_FILE"
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

# Static config
CONTAINER="$DB_HOST"
DB_USER="$DB_USERNAME"
DB_PASS="$DB_PASSWORD"
BACKUP_PASSWORD="$BACKUP_PASSWORD"
REMOTE="rclone-remote-name"
GDRIVE_FOLDER="Google-Drive-Folder-Path"
KEEP_LAST=5
