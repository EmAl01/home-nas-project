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
KEEP_COUNT=3	#how many recent NASPOOL snapshots to keep
TRANSFER_SPEED_MB=80  

echo "Starting daily backup: $(date)"
echo ""

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
# Snapshot management
# ===========================
echo "Checking existing snapshots"

LATEST_BACKUP_SNAP=$(zfs list -t snapshot -o name -s creation -r ${BACKUP} | grep "${BACKUP}@daily-" | tail -n 1 || true)
LATEST_NASPOOL_SNAP=$(zfs list -t snapshot -o name -s creation -r ${NASPOOL} | grep "${NASPOOL}@daily-" | tail -n 1 || true)
TODAY_SNAPSHOT="${NASPOOL}@daily-${TODAY}"

# Find common snapshot (same name, both sides exist)
COMMON_SNAPSHOT=""
if [ -n "$LATEST_BACKUP_SNAP" ]; then
	echo "Latest backup snap: $LATEST_BACKUP_SNAP"
	SNAP_NAME="${LATEST_BACKUP_SNAP##*@}"
	NASPOOL_MATCH="${NASPOOL}@${SNAP_NAME}"

	if zfs list -H -t snapshot -o name | grep -q "^${NASPOOL_MATCH}$"; then
		# Optional: compare GUIDs for absolute certainty
		B_GUID=$(zfs get -Hp -o value guid "$LATEST_BACKUP_SNAP")
		N_GUID=$(zfs get -Hp -o value guid "$NASPOOL_MATCH")
		if [ "$B_GUID" == "$N_GUID" ]; then
			COMMON_SNAPSHOT="$NASPOOL_MATCH"
			echo "Found common snapshot: $COMMON_SNAPSHOT"
		else
			echo "Snapshot names match but GUIDs differ — cannot use incremental."
		fi
	else
		echo "No matching snapshot found on NASPOOL side."
	fi
else
	echo "No backup snapshots found."
fi
echo "___"

# ===========================
# Deleting old snapshots (keep last 3)
# ===========================
echo "=== Deleting old NASPOOL snapshots (keeping ${KEEP_COUNT} + common) ==="
SNAPLIST=$(zfs list -H -t snapshot -o name -s creation | grep "^${NASPOOL}@daily-" || true)
KEEP_SNAPS=()

if [ -n "$COMMON_SNAPSHOT" ]; then
	KEEP_SNAPS+=("$COMMON_SNAPSHOT")
fi

LATEST_N=$(echo "$SNAPLIST" | tail -n $KEEP_COUNT)
KEEP_SNAPS+=($LATEST_N)

for SNAP in $SNAPLIST; do
	if ! echo "${KEEP_SNAPS[@]}" | grep -q "$SNAP"; then
		echo "Deleting old snapshot: $SNAP"
		zfs destroy "$SNAP" || echo "Couldn't delete $SNAP"
	fi
done
echo "___"

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
# Perform backup (incrementel or full)
# ===========================
echo "=== Starting backup process ==="
calculateestimatedtime "$TODAY_SNAPSHOT" "$TRANSFER_SPEED_MB"

if [ -n "$COMMON_SNAPSHOT" ]; then
	echo "Performing incremental backup:"
	echo "  From: $COMMON_SNAPSHOT"
	echo "  To:   $TODAY_SNAPSHOT"
	echo "___"

	if zfs send -i "$COMMON_SNAPSHOT" "$TODAY_SNAPSHOT" | zfs receive -F ${BACKUP}; then
		echo "Incremental backup successful."
	else
		echo "Incremental backup failed — performing full backup instead."
		zfs destroy -r ${BACKUP} || true
		zfs create ${BACKUP}
		zfs send "$TODAY_SNAPSHOT" | zfs receive -F ${BACKUP}
	fi
else
	echo "No common snapshot found — performing full backup."
	zfs destroy -r ${BACKUP} || true
	zfs create ${BACKUP}
	zfs send "$TODAY_SNAPSHOT" | zfs receive -F ${BACKUP}
fi

echo "Backup completed successfully at: $(date)"
echo "___"

# ===========================
# Shutting NAS down
# ===========================
echo "Backup completed: $(date)"
echo "Shutting down NAS."
sleep 3

/sbin/shutdown -h now
