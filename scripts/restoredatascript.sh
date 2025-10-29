#!/bin/bash
# Stop script execution if an error occurs
set -eo pipefail

# ===========================
# Creating log
# ===========================
TODAY=$(date +%Y-%m-%d)

LOGDIR="/usr/local/bin/backup/logs/restore"
LOGFILE="$LOGDIR/restoredatalog_${TODAY}.log"
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
USBBACKUP="usbbackup/subvol-100-disk-0"

echo "Starting restore data: $(date)"
echo ""

# ===========================
# Starting Container
# ===========================
containerstart() {
	echo "Restoring data completed: $(date)"
	echo "Restarting Container"
	sleep 3
	pct start 100 || true
	echo "Container started."
}

# ===========================
# Import usb zfs pool
# ===========================
importusbpool() {
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
}

# ===========================
# Export usb pool
# ===========================
exportusbpool() {
	echo "Exporting usb pool for safe detaching..."
	if zpool list | grep -q "^usbbackup"; then
		zpool export usbbackup
		echo "USB-Pool 'usbbackup' successfully exported."
	else
		echo "USB-Pool 'usbbackup' is not imported — skipping export."
	fi
}

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
# Restoring data
# ===========================
korpus() {
	echo "-----------------------------------------"
	echo "NAS Data Pool Restore"
	echo "-----------------------------------------"
	echo "Please choose a backup source:"
	echo "1) Internal backup drive"
	echo "2) External backup drive"
	echo "q) Quit"
	echo "-----------------------------------------"

	read -rp "Your choice [1/2/q]: " choice

	case "$choice" in
		1)
			echo "Using internal backup drive..."
			echo "Listing available ZFS snapshots for daily backup..."
			echo "___"

			mapfile -t SNAPSHOTS < <(zfs list -t snapshot -o name -s creation | grep "^${BACKUP}@daily")

			if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
				echo "No daily snapshots found for ${BACKUP}."
				return 1
			fi

			echo "Available daily snapshots:"
			for i in "${!SNAPSHOTS[@]}"; do
				echo "$((i+1))) ${SNAPSHOTS[$i]}"
			done
			echo "___"

			read -rp "Enter the number of the snapshot to restore: " snum
			if ! [[ "$snum" =~ ^[0-9]+$ ]] || [ "$snum" -lt 1 ] || [ "$snum" -gt "${#SNAPSHOTS[@]}" ]; then
				echo "Invalid selection. Aborting."
				return 1
			fi

			SNAPSHOT="${SNAPSHOTS[$((snum-1))]}"
			echo "___"
			echo "Restoring data with ${SNAPSHOT}"

			calculateestimatedtime "$SNAPSHOT" "80"

			zfs destroy -r "$NASPOOL"
			zfs send "$SNAPSHOT" | zfs receive -F "$NASPOOL"
			echo "Restore completed successfully."
			;;
		2)
			echo "Using external backup drive..."
			echo "___"
			echo "Checking for usb drive..."
			USBDEV=$(lsblk -o NAME,TRAN | awk '$2=="usb"{print "/dev/"$1; exit}')
			if [ -z "$USBDEV" ]; then
				echo "Error: No usb drive detected."
				echo "Please attach usb drive and run this script again."
				echo "Terminating script..."
				return 1
			fi
			echo "Found USB drive: $USBDEV"
			echo "___"

			importusbpool

			echo "Listing available ZFS snapshots for full backup..."
			mapfile -t SNAPSHOTS < <(zfs list -t snapshot -o name -s creation | grep "^${USBBACKUP}@full")

			if [ ${#SNAPSHOTS[@]} -eq 0 ]; then
				echo "No full snapshots found for ${USBBACKUP}."
				exportusbpool
				return 1
			fi

			echo "Available full snapshots:"
			for i in "${!SNAPSHOTS[@]}"; do
				echo "$((i+1))) ${SNAPSHOTS[$i]}"
			done
			echo "___"

			read -rp "Enter the number of the snapshot to restore: " snum
			if ! [[ "$snum" =~ ^[0-9]+$ ]] || [ "$snum" -lt 1 ] || [ "$snum" -gt "${#SNAPSHOTS[@]}" ]; then
				echo "Invalid selection. Aborting."
				exportusbpool
				return 1
			fi

			SNAPSHOT="${SNAPSHOTS[$((snum-1))]}"
			echo "___"
			read -rp "Are you sure you want to restore from this snapshot? (y/n): " confirm

			case "$confirm" in
				[Yy]*)
					echo "Restoring data with ${SNAPSHOT}"

					calculateestimatedtime "$SNAPSHOT" "100"

					zfs destroy -r "$NASPOOL"
					zfs send "$SNAPSHOT" | zfs receive -F "$NASPOOL"
					echo "Restore completed successfully."
					;;
				*)
					echo "Restore cancelled."
					;;
			esac
			exportusbpool
			;;
		q|Q)
			echo "Operation cancelled."
			return 1
			;;
		*)
			echo "Invalid input. Please choose 1, 2, or q."
			korpus  # Re-run until valid input
			;;
	esac
}

if korpus; then
	containerstart
else
	echo "Restore aborted or failed. Container will NOT be started."
	exit 1
fi
