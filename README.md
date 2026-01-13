# 🏠 Home NAS: Minimal, Boring, Stable

A no-nonsense Home NAS built using **plain Docker Compose**. Designed for predictability, recoverability, and simplicity.

**[Read the full guide on Medium](https://medium.com/@samarth_04/article-1-a-minimal-home-nas-setup-that-just-works-a9e87d5fb745)**

---

### 🧠 Core Philosophy

* **Simple > Over-engineered:** No Proxmox, no Kubernetes, no buzzwords.
* **Recoverable:** If it breaks, you should know exactly how to fix it.
* **Clean Separation:** Configs live in Git; data and secrets stay out.

### 📦 Repository Structure

Organized by **logical domains**, not just a list of containers:

* 📂 **`file_server/`**: Nextcloud, BentoPDF
* 📂 **`immich_app/`**: Photo management
* 📂 **`media_server/`**: Jellyfin, Sonarr, Radarr, qBittorrent, Jellyseerr, Qui, Komga
* 📂 **`monitoring/`**: Nginx
* 📂 **`misc/`**: Samba, Yamtrack

### 🚀 Usage

1. **Clone** this repo.
2. **Provide** your own `.env` files and data directories.
3. **Launch** services:
```bash
# Start everything
docker compose up -d

# Start a specific stack
docker compose up -d <service_name>

```

### 💾 Recovery Model

| Component | Storage Location |
| --- | --- |
| **Configs** | Git (this repo) |
| **Data** | Separate disks / Snapshots |
| **Secrets** | Manual / Password Manager |

**To restore:** Reinstall OS → Install Docker → Clone Repo → Mount Data → `up -d`.

### 🚧 Goals

* ✅ **Understandable & Repairable**
* ✅ **Human-readable recovery paths**
* ❌ **NOT** Enterprise HA or Multi-node.
