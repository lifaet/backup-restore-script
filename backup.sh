#!/bin/bash
set -euo pipefail

# Load env & config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

# Ensure BACKUP_PASSWORD is set in config.sh
if [[ -z "${BACKUP_PASSWORD:-}" ]]; then
    echo "❌ BACKUP_PASSWORD is not set in config.sh!"
    exit 1
fi

# Discover databases (kept in main script)
DB_LIST=$(grep -E '^DB_DATABASE[0-9]*' "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$DB_LIST" ]]; then
    echo "❌ No databases defined in .env!"
    exit 1
fi

TIMESTAMP=$(date +"_%Y%m%d_%H%M%S")

for DB_NAME in $DB_LIST; do
    echo "→ Backing up database: $DB_NAME at $(date +"%Y-%m-%d %H:%M:%S")"

    BACKUP_FILE="${DB_NAME}${TIMESTAMP}.sql.enc"
    DB_FOLDER="$GDRIVE_FOLDER/$DB_NAME"

    mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" | \
    openssl enc -aes-256-cbc -salt -pass pass:"$BACKUP_PASSWORD" -out "/tmp/$BACKUP_FILE"

    rclone mkdir "$REMOTE:$DB_FOLDER" || true
    rclone copy "/tmp/$BACKUP_FILE" "$REMOTE:$DB_FOLDER"

    BACKUPS=$(rclone lsf "$REMOTE:$DB_FOLDER" --files-only | sort)
    TOTAL=$(echo "$BACKUPS" | wc -l)

    if [ "$TOTAL" -gt "$KEEP_LAST" ]; then
        REMOVE=$(echo "$BACKUPS" | head -n $(($TOTAL - $KEEP_LAST)))
        for f in $REMOVE; do
            rclone delete "$REMOTE:$DB_FOLDER/$f"
        done
    fi

    rm -f "/tmp/$BACKUP_FILE"
    echo "✓ $DB_NAME backup completed."
done

echo "🎉 All databases backed up and encrypted successfully!"