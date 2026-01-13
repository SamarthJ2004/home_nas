#!/bin/bash
set -euo pipefail

################ CONFIG ################

BACKUP_ROOT="/mnt/hdd1tb/backups"
SNAPSHOTS="$BACKUP_ROOT/snapshots"
VIEW="/home/pari/backup_view"
HOME_NAS="/home/pari/home_nas"

RETENTION_DAYS=180
MIN_FREE_GB=10

LOG="/var/log/snapshot_backup.log"

LOCK_FILE="/var/lock/snapshot_backup.lock"
LOCK_FD=9

TODAY="$(date +%F)"

#######################################

cleanup_mounts() {
  for p in \
    "$VIEW/hdd4tb/files" \
    "$VIEW/hdd4tb/immich" \
    "$VIEW/home_nas/immich_app"
  do
    mountpoint -q "$p" && umount "$p" || true
  done
}

finish() {
  status=$?
  cleanup_mounts

  if [ "$status" -eq 0 ]; then
    echo "=== Backup finished successfully at $(date) ===" >> "$LOG"
  else
    echo "=== Backup FAILED at $(date) (exit code $status) ===" >> "$LOG"
  fi
}
trap finish EXIT

#######################################
# Safety checks
#######################################

[ "$(id -u)" -eq 0 ] || { echo "Must run as root" >> "$LOG"; exit 1; }

for cmd in rsync mount umount df flock date mountpoint; do
  command -v "$cmd" >/dev/null || { echo "$cmd missing" >> "$LOG"; exit 1; }
done

exec {LOCK_FD}>"$LOCK_FILE"
flock -n "$LOCK_FD" || exit 0

#######################################
echo "=== Backup started at $(date) ===" >> "$LOG"

mkdir -p \
  "$SNAPSHOTS" \
  "$BACKUP_ROOT/daily" \
  "$VIEW/hdd4tb/files" \
  "$VIEW/hdd4tb/immich" \
  "$VIEW/home_nas/immich_app" \
  "$VIEW/home_nas/configs"

#######################################
# Bind mounts (read-only)
#######################################

cleanup_mounts

mount --bind /mnt/hdd4tb/files "$VIEW/hdd4tb/files"
mount --bind /mnt/hdd4tb/immich "$VIEW/hdd4tb/immich"
mount --bind "$HOME_NAS/immich_app" "$VIEW/home_nas/immich_app"

mount -o remount,bind,ro "$VIEW/hdd4tb/files"
mount -o remount,bind,ro "$VIEW/hdd4tb/immich"
mount -o remount,bind,ro "$VIEW/home_nas/immich_app"

#######################################
# Disk space check
#######################################

FREE_GB=$(df --output=avail -BG "$BACKUP_ROOT" | tail -1 | tr -dc '0-9')

if [ "$FREE_GB" -lt "$MIN_FREE_GB" ]; then
  echo "Low disk space: ${FREE_GB}GB free" >> "$LOG"
  exit 1
fi

#######################################
# Collect configs
#######################################

rsync -a --delete --prune-empty-dirs \
  --include='*/' \
  --include='*.yml' \
  --include='*.env' \
  --include='backup_snapshot.sh' \
  --exclude='*' \
  "$HOME_NAS/" \
  "$VIEW/home_nas/configs/"

#######################################
# Snapshot creation
#######################################

DEST="$SNAPSHOTS/$TODAY"
PREV="$(readlink -f "$BACKUP_ROOT/daily/latest" 2>/dev/null || true)"

mkdir -p "$DEST"

RSYNC_OPTS=(
  -aAXH
  --numeric-ids
  --delete-after
  --partial
  --inplace
  --ignore-errors
  --exclude='*.sock'
  --exclude='*.pid'
  --exclude='*.lock'
)

if [ -n "$PREV" ] && [ -d "$PREV" ] && [ -f "$PREV/.snapshot_complete" ] && [ "$PREV" != "$SNAPSHOTS/$TODAY" ]; then
  echo "Incremental snapshot using link-dest=$PREV" >> "$LOG"
  rsync "${RSYNC_OPTS[@]}" --link-dest="$PREV" "$VIEW/" "$DEST/"
else
  echo "First snapshot or fallback full sync" >> "$LOG"
  rsync "${RSYNC_OPTS[@]}" "$VIEW/" "$DEST/"
fi

touch "$DEST/.snapshot_complete"

ln -sfn "$DEST" "$BACKUP_ROOT/daily/latest"

#######################################
# Pruning (date-based, safe)
#######################################

ls -1d "$SNAPSHOTS/"[0-9]* 2>/dev/null \
  | sort \
  | head -n "-$RETENTION_DAYS" \
  | xargs -r rm -rf

FREE_GB_AFTER=$(df --output=avail -BG "$BACKUP_ROOT" | tail -1 | tr -dc '0-9')
echo "Backup completed. Free space remaining: ${FREE_GB_AFTER}GB" >> "$LOG"

