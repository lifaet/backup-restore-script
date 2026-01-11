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

# Fetch all DB_DATABASE* variables from .env
DB_LIST=$(grep -E '^DB_DATABASE[0-9]*' "$ENV_FILE" | cut -d '=' -f2)

if [[ -z "$DB_LIST" ]]; then
    echo "❌ No databases defined in .env!"
    exit 1
fi

for DB_NAME in $DB_LIST; do
    echo "→ Processing database: $DB_NAME"

    # Find latest backup for this database
    LATEST_BACKUP=$(rclone lsf "$REMOTE:$GDRIVE_FOLDER/$DB_NAME" --files-only | sort | tail -n 1)
    if [[ -z "$LATEST_BACKUP" ]]; then
        echo "⚠️ No backup found for $DB_NAME! Skipping."
        continue
    fi
    echo "→ Latest backup for $DB_NAME: $LATEST_BACKUP"

    # Confirm restore
    read -p "⚠️ Restore '$DB_NAME' from '$LATEST_BACKUP'? (yes/no): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        echo "Restore cancelled for $DB_NAME."
        continue
    fi

    # Download backup
    TMP_FILE="/tmp/$LATEST_BACKUP"
    rclone copy "$REMOTE:$GDRIVE_FOLDER/$DB_NAME/$LATEST_BACKUP" "/tmp/"

    # Restore database
    echo "→ Restoring $DB_NAME..."
    cat "$TMP_FILE" | mysql -u"$DB_USER" -p"$DB_PASS" "$DB_NAME"

    # Cleanup
    rm "$TMP_FILE"
    echo "✓ $DB_NAME restored successfully."
done

echo "🎉 All available databases restored successfully!"
