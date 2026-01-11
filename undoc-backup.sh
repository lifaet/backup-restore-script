#!/bin/bash
set -euo pipefail

# Load .env from parent directory
ENV_FILE="../.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env not found!"
    exit 1
fi
set -a; source "$ENV_FILE"; set +a

# Config
CONTAINER="$DB_HOST"
DB_USER="$DB_USERNAME"
DB_PASS="$DB_PASSWORD"
REMOTE="encompos"
GDRIVE_FOLDER="Databases/ENCOMPOS/TEST"
KEEP_LAST=5

# Fetch all DB_DATABASE* variables from .env
DB_LIST=$(grep -E '^DB_DATABASE[0-9]*' "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$DB_LIST" ]]; then
    echo "❌ No databases defined in .env!"
    exit 1
fi

# Timestamp
TIMESTAMP=$(date +"_%Y%m%d_%H%M%S")

for DB_NAME in $DB_LIST; do
    echo "→ Backing up database: $DB_NAME" at $(date +"%Y-%m-%d %H:%M:%S")

    BACKUP_FILE="${DB_NAME}${TIMESTAMP}.sql"
    DB_FOLDER="$GDRIVE_FOLDER/$DB_NAME"

    # Dump DB
    mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" > "/tmp/$BACKUP_FILE"

    # Upload to Google Drive
    rclone mkdir "$REMOTE:$DB_FOLDER" || true
    rclone copy "/tmp/$BACKUP_FILE" "$REMOTE:$DB_FOLDER"

    # Cleanup old backups
    BACKUPS=$(rclone lsf "$REMOTE:$DB_FOLDER" --files-only | sort)
    TOTAL=$(echo "$BACKUPS" | wc -l)
    if [ "$TOTAL" -gt "$KEEP_LAST" ]; then
        REMOVE=$(echo "$BACKUPS" | head -n $(($TOTAL - $KEEP_LAST)))
        for f in $REMOVE; do
            echo "→ Removing old backup: $f"
            rclone delete "$REMOTE:$DB_FOLDER/$f"
        done
    fi

    rm "/tmp/$BACKUP_FILE"
    echo "✓ $DB_NAME backup completed successfully."
done

echo "🎉 All available databases backed up successfully!"
