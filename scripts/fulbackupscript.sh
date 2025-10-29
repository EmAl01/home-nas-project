#!/bin/bash
# Stop script execution if an error occurs
set -eo pipefail

# ===========================
# Creating log
# ===========================
TODAY=$(date +%Y-%m-%d)

LOGDIR="/usr/local/bin/backup/logs/full"
LOGFILE="$LOGDIR/fullbackuplog_${TODAY}.log"
mkdir -p "$LOGDIR"
exec > >(tee -a "$LOGFILE") 2>&1

# ===========================
# Check for usb drive
# ===========================
USBDEV=$(lsblk -o NAME,TRAN | awk '$2=="usb"{print "/dev/"$1; exit}')
if [ -z "$USBDEV" ]; then
	echo "Error: No USB drive detected."
	echo "Terminating script..."
	exit 1
fi
echo "Found USB drive: $USBDEV"

# ===========================
# Configuration
# ===========================
# Stopping running container (ignore errors)
pct stop 100 || true
echo "___"

NASPOOL="naspool/subvol-100-disk-0"
USBBACKUP="usbbackup/subvol-100-disk-0"

echo "Starting full backup: $(date)"
echo ""

# ===========================
# Deleting old Snapshots (keep last 3)
# ===========================
echo "Deleting old snapshots in $NASPOOL (keeping the last 3):"

# List all 'full' snapshots, oldest first
SNAPLIST=$(zfs list -H -t snapshot -o name -s creation | grep "^${NASPOOL}@full-" || true)

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

# ===========================
# Creating new NASPOOL snapshot
# ===========================
if ! zfs list -t snapshot | grep -q "${NASPOOL}@full-${TODAY}"; then
	echo "Creating new snapshot: ${NASPOOL}@full-${TODAY}"
	zfs snapshot "${NASPOOL}@full-${TODAY}"
	echo "___"
else
	echo "Snapshot ${NASPOOL}@full-${TODAY} already exists."
	echo "___"
fi


# ===========================
# Import usb zfs pool
# ===========================
echo "Checking usb zfs pool..."
if ! zpool list | grep -q "^usbbackup"; then
	echo "Zfs pool 'usbbackup' not imported – attempting import..."
	if zpool import | grep -q "usbbackup"; then
		zpool import usbbackup
		echo "Zfs pool 'usbbackup' successfully imported"
	else
		echo "Error: No Zfs pool named 'usbbackup' found!"
		echo "Terminating script..."
		exit 1
	fi
else
	echo "Zfs pool 'usbbackup' already imported."
fi
echo "___"

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
# Sending backup to usb pool
# ===========================
echo "Sending backup to usb pool..."
echo "___"

calculateestimatedtime "$NASPOOL" "25"

if ! zfs list "$USBBACKUP" >/dev/null 2>&1; then
	echo "No previous backup found – creating initial full backup..."
	zfs send "${NASPOOL}@full-${TODAY}" | zfs receive "$USBBACKUP"
else
	echo "Existing backup detected - deleting old dataset and creating new one"
	zfs destroy -r "$USBBACKUP" || true
	zfs create -p "$USBBACKUP"
	zfs send "${NASPOOL}@full-${TODAY}" | zfs receive -F "$USBBACKUP"
fi
echo "Backup transfer completed"
echo "___"

# ===========================
# Export usb pool
# ===========================
echo "Exporting usb pool for safe detaching..."
zpool export usbbackup
echo "USB-Pool 'usbbackup' successfully exported."

# ===========================
# Starting Container
# ===========================
echo "Full backup completed: $(date)"
echo "Restarting Container"
sleep 3
pct start 100 || true
echo "Container started."
