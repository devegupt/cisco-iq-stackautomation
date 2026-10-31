#!/usr/bin/env bash
# download-ova.sh <ova_url> [--placeholder]
# Caches the OVA on the Stack Automation runner so the Terraform grain can deploy it
# with local_ovf_path. Cache dirs must match terraform/iqlink-ova var.ova_cache_dirs.
#   --placeholder : used before terraform destroy; if the cached OVA is gone, create an
#                   empty file at the expected path so the vSphere provider can still
#                   read its configuration and delete the VM.
# Stack Automation runs pre-tf-* scripts with `source`; re-run in a child bash so our
# `set -e`/`exit` cannot leak into, or end, the runner's shell.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then bash "${BASH_SOURCE[0]}" "$@"; return $?; fi
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
AVAIL_KB=$(df -Pk "$DIR" | awk 'NR==2{print $4}')   # integer KB (bytes overflow awk into 1.5e+11)
if [[ -n "$EXPECTED" ]] && (( AVAIL_KB < EXPECTED / 1024 + 1048576 )); then
  log "ERROR: not enough space in $DIR (need $((EXPECTED / 1048576)) MB + 1 GB headroom, have $((AVAIL_KB / 1024)) MB)"; exit 1
fi
log "free space in $DIR: $((AVAIL_KB / 1048576)) GB"

size_of() { stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || echo 0; }

# A complete .part from an earlier run (e.g. one that failed after downloading) is reused.
if [[ -n "$EXPECTED" && -f "$DIR/$FILE.part" && "$(size_of "$DIR/$FILE.part")" == "$EXPECTED" ]]; then
  log "Reusing complete partial download $DIR/$FILE.part"
else
  curl -fSL --retry 5 --retry-delay 10 --connect-timeout 30 -C - -o "$DIR/$FILE.part" "$URL"
fi
ACTUAL=$(size_of "$DIR/$FILE.part")
if [[ -n "$EXPECTED" && "$ACTUAL" != "$EXPECTED" ]]; then
  log "ERROR: size mismatch (expected $EXPECTED, got $ACTUAL)"; exit 1
fi
# No `grep -q` here: it closes the pipe early, tar gets SIGPIPE and pipefail fails the check.
OVF=$(tar -tf "$DIR/$FILE.part" | grep '\.ovf$' || true)
[[ -n "$OVF" ]] || { log "ERROR: $FILE is not a valid OVA (no .ovf inside)"; exit 1; }
log "OVA contains $OVF"
mv "$DIR/$FILE.part" "$DIR/$FILE"
log "OVA cached: $DIR/$FILE ($ACTUAL bytes)"
