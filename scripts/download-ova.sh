#!/usr/bin/env bash
# download-ova.sh <ova_url> [--placeholder]
# Caches the OVA on the Stack Automation runner so the Terraform grain can deploy it
# with local_ovf_path. Cache dirs must match terraform/iqlink-ova var.ova_cache_dirs.
#   --placeholder : used before terraform destroy; if the cached OVA is gone, create an
#                   empty file at the expected path so the vSphere provider can still
#                   read its configuration and delete the VM.
set -euo pipefail

URL="${1:?usage: download-ova.sh <ova_url> [--placeholder]}"
MODE="${2:-}"
FILE="$(basename "${URL%%\?*}")"
CANDIDATES=(/storage/ova-cache /tmp/ova-cache)

log() { echo "[$(date -u +%H:%M:%S)] $*"; }

for d in "${CANDIDATES[@]}"; do
  if [[ -s "$d/$FILE" ]]; then log "OVA already cached: $d/$FILE ($(du -h "$d/$FILE" | cut -f1))"; exit 0; fi
done

DIR=""
for d in "${CANDIDATES[@]}"; do
  if mkdir -p "$d" 2>/dev/null && [[ -w "$d" ]]; then DIR="$d"; break; fi
done
[[ -n "$DIR" ]] || { log "ERROR: no writable cache dir among: ${CANDIDATES[*]}"; exit 1; }

if [[ "$MODE" == "--placeholder" ]]; then
  : > "$DIR/$FILE"
  log "Created empty placeholder $DIR/$FILE for destroy"
  exit 0
fi

log "Downloading $URL -> $DIR/$FILE"
EXPECTED=$(curl -fsSIL "$URL" | awk 'tolower($1)=="content-length:"{v=$2} END{gsub("\r","",v); print v}')
AVAIL=$(df -Pk "$DIR" | awk 'NR==2{print $4*1024}')
if [[ -n "$EXPECTED" && "$AVAIL" -lt "$EXPECTED" ]]; then
  log "ERROR: not enough space in $DIR (need $EXPECTED bytes, have $AVAIL)"; exit 1
fi

curl -fSL --retry 5 --retry-delay 10 --connect-timeout 30 -C - -o "$DIR/$FILE.part" "$URL"
ACTUAL=$(stat -c %s "$DIR/$FILE.part" 2>/dev/null || stat -f %z "$DIR/$FILE.part")
if [[ -n "$EXPECTED" && "$ACTUAL" != "$EXPECTED" ]]; then
  log "ERROR: size mismatch (expected $EXPECTED, got $ACTUAL)"; exit 1
fi
tar -tf "$DIR/$FILE.part" | grep -q '\.ovf$' || { log "ERROR: $FILE is not a valid OVA (no .ovf inside)"; exit 1; }
mv "$DIR/$FILE.part" "$DIR/$FILE"
log "OVA cached: $DIR/$FILE ($ACTUAL bytes)"
