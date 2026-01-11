#!/bin/bash
set -euo pipefail

# Load env & config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"


# Timestamp
TIMESTAMP=$(date +"_%Y%m%d_%H%M%S")

echo "→ Fetching database list from container $CONTAINER..."
DATABASES=$(docker exec -i "$CONTAINER" mysql -u"$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" \
  | grep -Ev "Database|information_schema|performance_schema|mysql|sys")

for DB in $DATABASES; do
    BACKUP_FILE="${DB}${TIMESTAMP}.sql"
    DB_FOLDER="$BASE_FOLDER/$DB"

    echo "→ Backing up database: $DB"
    docker exec -i "$CONTAINER" mysqldump -u"$DB_USER" -p"$DB_PASS" "$DB" > "/tmp/$BACKUP_FILE"

    echo "→ Uploading $BACKUP_FILE to Google Drive ($REMOTE:$DB_FOLDER)..."
    rclone mkdir "$REMOTE:$DB_FOLDER" || true
    rclone copy "/tmp/$BACKUP_FILE" "$REMOTE:$DB_FOLDER"

    # Cleanup old backups in Drive
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
    echo "✓ $DB backup completed successfully."
done
echo "🎉 All databases backed up successfully!"
