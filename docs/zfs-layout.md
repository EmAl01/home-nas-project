## ZFS pool configuration
| Pool | Disks | Purpose | RAID | Mountpoint |
|------|-------|---------|------|------------|
| `naspool` | 2x 1TB 3.5" HDD (Toshiba) | Main pool | mirror (Raid 1) | `/mnt/naspool` |
| `backup` | 1x 1TB 2.5" HDD (Seagate) | Daily incremental backups | Single | `/mnt/backup` |
| `usbbackup` | 1x 2TB usb SSD (Toshiba) | Weekly full backups | Single | `/mnt/usbbackup` |

---
Advantages for using ZFS:
- Snapshots enable efficient incremental backups
- Send/Receive allows fast and reliable data transfers between pools
- Self-healing automatically corrects data errors using redundancy
- Compression (e.g. lz4) reduces storage usage and improves performance
