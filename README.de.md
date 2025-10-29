# home-nas-project
DIY-NAS mit automatisierten inkrementellen und vollständigen ZFS-Backups, Logging und Wiederherstellungsskripten

## Beschreibung
Dieses Projekt implementiert eine vollständig automatisierte Backup- und Wiederherstellungsumgebung für ein Eigenheim NAS-System.
Es verwendet ZFS-Snapshots, inkrementelle und vollständige Backups, eigene Bash-Automatisierung und ein strukturiertes Log-System, um sichere, nachvollziehbare und wiederholbare Datenoperationen zu gewährleisten.
Das System ist innerhalb des lokalen Netzwerks isoliert und auf langfristige Zuverlässigkeit sowie einfache Wiederherstellung ausgelegt.

## Warum dieses Projekt?
Als Softwareentwickler wollte ich mein Verständnis für Systemadministration, Datensicherheit und Automatisierung in Linux-Umgebungen vertiefen.
Anstatt auf vorgefertigte NAS-Software (wie TrueNAS oder OpenMediaVault) zurückzugreifen, habe ich alles manuell aufgebaut, um wirklich zu verstehen:

- wie Speicherpools, Snapshots und Redundanz in ZFS funktionieren
- wie Automatisierung und Logging Backups zuverlässig gemacht werden können
- wie man Sicherheit und Benutzerfreundlichkeit in einer selbst gehosteten Umgebung implementiert

Dieses Projekt verbindet Softwareentwicklung und Infrastruktur-Engineering — und macht aus Theorie praktische Erfahrung.

## Systemübersicht
**Hardware**
- HP EliteDesk 800 G3 SFF  
- 2× Toshiba 3.5" 1TB HDDs (RAID 1 via ZFS Mirror → `naspool`)  
- 1× 2.5" 1TB HDD (internes inkrementelles Backup → `backup`)  
- 1× 2TB USB SSD (externes vollständiges Backup → `usbbackup`)  
- 256GB NVMe SSD (Proxmox-Systemlaufwerk)

**Softwarearchitektur**
- Host-System: Proxmox VE
- Proxmox Node: ZFS + ZFS-Snapshots zur Versionskontrolle + automatisierte Backups über Cron + lokale Logdateien
- LXC-Container: Ubuntu Server + Samba
- Samba: Private Benutzerverzeichnisse (passwortgeschützt) + gemeinsames "public"-Verzeichnis für Dateiaustausch innerhalb der Familie

**Netzwerk**
- Statische IP-Adresse (außerhalb des DHCP-Bereichs)
- Firewall: Zugriff ausschließlich innerhalb des lokalen LAN
- SSH-Zugang deaktiviert — Verwaltung nur über die Proxmox-Oberfläche oder physische Konsole

## Skriptübersicht

| Skript | Zweck | Hauptfunktionen |
|--------|----------|---------------|
| `inkrembackupscript.sh` | Automatisiert tägliche **inkrementelle ZFS-Backups** | - Behält die letzten 3 Snapshots<br>- Schätzt Backup-Dauer<br>- Protokolliert alle Aktionen<br>- Fährt NAS nach Abschluss herunter |
| `fullbackupscript.sh` | Führt **manuelle vollständige Backups** auf externe USB-Laufwerke aus | - Erkennt USB-Gerät automatisch<br>- Importiert/exportiert ZFS-Pool<br>- Startet Container nach Backup neu |
| `restoredatascript.sh` | Stellt Daten aus internen oder externen Backups wieder her | - Interaktives Menü<br>- Snapshot-Auswahl<br>- Schätzung der Wiederherstellungsdauer<br>- Automatischer Neustart des Containers |

**Gemeinsame Eigenschaften**
- Vollständig in Bash geschrieben  
- Nutzt `set -eo pipefail` für strikte Fehlerbehandlung
- Schritt-für-Schritt-Ausgabe im Terminal
- Alle Logs unter `/usr/local/bin/backup/logs/` gespeichert 
- Vollständig eigenständig — keine externen Abhängigkeiten

## Sicherheitsaspekte

- NAS ist **nur innerhalb des lokalen Netzwerks** erreichbar
- **SSH deaktiviert,** um die Angriffsfläche zu minimieren
- **ZFS-Snapshots** schützen vor Datenkorruption und versehentlichem Löschen
- **Protokollierung** ermöglicht Nachvollziehbarkeit und einfacheres Debugging
- Automatisches **Herunterfahren** nach täglichen Backups reduziert Stromverbrauch und Hardwareverschleiß
- **Manuelle Wiederherstellung** verhindert versehentliches Überschreiben

## Ziele & Lernfokus

Dieses Projekt wurde entwickelt, um meine Kenntnisse in folgenden Bereichen zu vertiefen:

- **Linux-Systemadministration**
- **Proxmox-Virtualisierung und LXC-Verwaltung**
- **ZFS-Speicherkonzepte** (Pools, Snapshots, inkrementelle Übertragungen)
- **Shell-Scripting und Automatisierung**
- **Backup-Strategien (3–2–1-Prinzip)**
- **Betriebssicherheit und Netzwerktrennung**
- **Fehlerbehandlung und Logging-Best-Practices**

Abgesehen von den technischen Zielen war es eine persönliche Herausforderung, ein **vollständig wartbares**, **praxisnahes System** von Grund auf aufzubauen — ohne auf GUI-basierte NAS-Tools zurückzugreifen.

## Geplante Erweiterungen

- Hinzufügen von **E-Mail-Benachrichtigungen** für Backup-Ergebnisse

## Fazit

Dieses Projekt zeigt, wie man eine **zuverlässige und automatisierte Dateninfrastruktur** von Grund auf aufbaut.
Es spiegelt ein tiefes Verständnis von **Systemdesign, Fehlertoleranz, Automatisierung und Wartbarkeit** wider — essentielle Fähigkeiten, die über klassische Softwareentwicklung hinausgehen.

Durch die Kombination von **Proxmox, ZFS und Bash-Scripting** erreicht das System:
- Datenredundanz
- Automatisierung ohne externe Abhängigkeiten
- Transparente Protokollierung
- Und vollständige Kontrolle über Datenintegrität

---

## Autor

**Emre Altunok**  
Staatlich anerkannter Fachinformatiker für Anwendungsentwicklung und leidenschaftlich dabei für Linux, Automatisierung und Self-Hosting  

> 🌍 Verfügbare Sprachen: [English (README.md)](./README.md)
