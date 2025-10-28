# home-nas-project
DIY NAS with automated incremental and full ZFS backups, logging and restore scripts

## Description
This project implements a fully automated backup and recovery environment for a home NAS system.  
It uses **ZFS snapshots**, **incremental and full backups**, **custom Bash automation**, and a **structured logging system** to ensure safe, traceable, and repeatable data operations.  
The system is isolated within a local network and is designed for long-term reliability and easy restoration.

## Why this project?
As a Software Developer, I wanted to deepen my understanding of **system administration**, **data security**, and **automation in Linux environments**.  
Instead of using prebuilt NAS software (like TrueNAS or OpenMediaVault), I built everything manually to fully understand:

- how storage pools, snapshots, and redundancy work in ZFS  
- how automation and logging can make backups reliable  
- how to balance security and usability in a self-hosted environment  

This project bridges the gap between **software development** and **infrastructure engineering** — turning theory into practice.

## System Overview
**Hardware**
- HP EliteDesk 800 G3 SFF  
- 2× Toshiba 3.5" 1TB HDDs (RAID 1 via ZFS mirror → `naspool`)  
- 1× 2.5" 1TB HDD (internal incremental backup → `backup`)  
- 1× 2TB USB SSD (external full backup → `usbbackup`)  
- 256GB NVMe SSD (Proxmox system drive)

**Software Architecture**
- Host System: Proxmox VE
- Proxmox Node: ZFS + ZFS snapshots for version control + Automated backups managed via cron + Log files stored locally
- LXC container: Ubuntu Server + Samba
- Samba: Private user directories (password protected) + Shared "public" directory for family file exchange

**Network**
- Static IP address (outside DHCP range)
- Firewall: access restricted to local LAN only
- SSH access disabled — management only via Proxmox UI or physical console

## Script Overview

| Script | Purpose | Key Features |
|--------|----------|---------------|
| `inkrembackupscript.sh` | Automates daily **incremental ZFS backups** | - Keeps last 3 snapshots<br>- Estimates backup duration<br>- Logs all actions<br>- Shuts down NAS after completion |
| `fullbackupscript.sh` | Performs **manual full backup** to external USB drive | - Detects USB device automatically<br>- Imports/export ZFS pool<br>- Restarts container after backup |
| `restoredatascript.sh` | Restores data from internal or external backups | - Interactive menu<br>- Snapshot selection<br>- Estimated restore duration<br>- Automatic container restart |

**Common characteristics**
- Written entirely in Bash  
- Uses `set -eo pipefail` for strict error handling  
- Step-by-step terminal feedback  
- All logs stored under `/usr/local/bin/backup/logs/`  
- Fully self-contained — no external dependencies

## Security Considerations

- NAS accessible **only within the local network**
- **SSH disabled** to minimize attack surface
- **ZFS snapshots** provide protection against corruption and accidental deletions
- **Logging** ensures traceability and easier troubleshooting
- Automated **shutdown** after daily backups reduces power usage and wear
- **Manual restore process** prevents accidental overwrites

## Goals & Learning Focus

This project was designed to strengthen my skills in:

- **Linux system administration**
- **Proxmox virtualization and LXC management**
- **ZFS storage concepts** (pools, snapshots, incremental sends)
- **Shell scripting and automation**
- **Backup strategy design (3–2–1 principle)**
- **Operational security and network isolation**
- **Error handling and logging best practices**

Beyond the technical goals, it was also a personal challenge to build a **fully maintainable, real-world system** from scratch — without relying on GUI-driven NAS tools.

## Additional Improvements (Planned)

- Add **email notifications** for backup results

## Conclusion

This project helps to understand how a **reliable and automated data infrastructure** is build from the ground up.  
It reflects a deep understanding of **system design, fault tolerance, automation, and maintainability** — essential skills that go beyond traditional application development.  

By combining **Proxmox, ZFS, and Bash scripting**, the system achieves:
- data redundancy  
- automation without dependencies  
- transparent logging  
- and full control over data integrity.

---

## Author

**Emre Altunok**  
Software Developer  
Passionate about Linux, automation, and self-hosted solutions  

> 🌍 Available languages: [Deutsch (README.de.md)](./README.de.md)
