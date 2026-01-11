#!/bin/bash
set -euo pipefail

# Resolve directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env from parent directory of the script
ENV_FILE="$SCRIPT_DIR/../.env"
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
BASE_FOLDER="Databases/ENCOMPOS/TEST"
KEEP_LAST=5


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
