#!/bin/bash
# Stop script execution if an error occurs
set -eo pipefail

# ===========================
# Creating log
# ===========================
TODAY=$(date +%Y-%m-%d)

LOGDIR="/usr/local/bin/backup/logs/daily"
LOGFILE="$LOGDIR/dailybackuplog_${TODAY}.log"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGFILE") 2>&1

# ===========================
# Configuration
# ===========================
# Stopping running container (ignore errors)
pct stop 100 || true
echo "___"

NASPOOL="naspool/subvol-100-disk-0"
BACKUP="backup/subvol-100-disk-0"

echo "Starting daily backup: $(date)"
echo ""

# ===========================
# Deleting old snapshots (keep last 3)
# ===========================
for TARGET in "$NASPOOL" "$BACKUP"; do
        echo "Deleting old snapshots in $TARGET (keeping the last 3):"

        # List all 'daily' snapshots, oldest first
        SNAPLIST=$(zfs list -H -t snapshot -o name -s creation | grep "^${TARGET}@daily-" || true)

        # Count how many snapshots exist
        if [ -n "$SNAPLIST" ]; then
                SNAPCOUNT=$(echo "$SNAPLIST" | wc -l)
        else
                SNAPCOUNT=0
        fi

        # If there are more than 3, delete the oldest ones
        if [ "$SNAPCOUNT" -gt 3 ]; then
                TODELETE=$((SNAPCOUNT - 3))
                echo "Found $SNAPCOUNT snapshots, deleting $TODELETE oldest..."
                echo "$SNAPLIST" | head -n "$TODELETE" | while read -r SNAP; do
                        echo "Deleting snapshot: $SNAP"
                        zfs destroy "$SNAP" || echo "Couldn't delete $SNAP"
                done
        else
                echo "Less than 3 snapshots found ($SNAPCOUNT) - nothing to delete."
        fi
        echo "___"
done

# ===========================
# Creating new NASPOOL snapshot
# ===========================
if ! zfs list -t snapshot | grep -q "${NASPOOL}@daily-${TODAY}"; then
	echo "Creating new snapshot: ${NASPOOL}@daily-${TODAY}"
	zfs snapshot "${NASPOOL}@daily-${TODAY}"
	echo "___"
else
	echo "Snapshot ${NASPOOL}@daily-${TODAY} already exists."
	echo "___"
fi

# ===========================
# Calculating estimated time
# ===========================
calculateestimatedtime() {
	local SOURCE="$1"
	local SPEED_MBPS="$2"

	if ! zfs list "$SOURCE" >/dev/null 2>&1; then
		echo "Error: Source dataset '$SOURCE' not found."
		return 1
	fi

	# Calculating Dataset size (Bytes)
	local DATA_SIZE=$(zfs get -Hp -o value refer "$SOURCE")

	# Average usb/sata transfer speed (Bytes per seconds)
	local TRANSFER_SPEED=$((SPEED_MBPS*1024*1024))  # 100 MB/s

	# Calculating estimated time (seconds)
	local EST_DURATION=$((DATA_SIZE / TRANSFER_SPEED))

	# H:min:sec
	local H=$((EST_DURATION/3600))
	local M=$(((EST_DURATION%3600)/60))
	local S=$((EST_DURATION%60))

	local END_TIME=$(date -d "+${EST_DURATION} seconds" +"%H:%M")

	echo "Dataset size: $((DATA_SIZE/1024/1024)) MB"
	echo "Estimated transfer time (${SPEED_MBPS} MB/s): ${H}h ${M}m ${S}s"
	echo "Estimated finish time: ${END_TIME}"
	echo "___"
}

# ===========================
# Sending backup
# ===========================
echo "Sending backup to backup pool..."
LAST_BACKUP=$(zfs list -t snapshot -o name -s creation -r ${BACKUP} | tail -n 1)

if [ -n "$LAST_BACKUP" ]; then
	SNAPNAME="${LAST_BACKUP##*@}"
	LAST_NASPOOL_SNAPSHOT="${NASPOOL}@${SNAPNAME}"

	if zfs list -t snapshot | grep -q "$LAST_NASPOOL_SNAPSHOT" && [ "$SNAPNAME" != "daily-${TODAY}" ]; then
		echo "Incremental backup from $LAST_NASPOOL_SNAPSHOT to ${NASPOOL}@daily-${TODAY}"
		echo "___"

		calculateestimatedtime "$LAST_NASPOOL_SNAPSHOT" "80"

		zfs send -i "$LAST_NASPOOL_SNAPSHOT" "${NASPOOL}@daily-${TODAY}" | zfs receive -F ${BACKUP}
	else
		echo "No valid snapshot found or backup already up to date"
		echo "No incremental backup performed."
	fi
else
	echo "No existing backup snapshot found."
	echo "Performing full backup..."
	echo "___"

	calculateestimatedtime "$NASPOOL" "80"

	zfs send "${NASPOOL}@daily-${TODAY}" | zfs receive -F ${BACKUP}
fi
echo "___"

# ===========================
# Shutting NAS down
# ===========================
echo "Backup completed: $(date)"
echo "Shutting down NAS."
sleep 3

/sbin/shutdown -h now
