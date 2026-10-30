#!/usr/bin/env bash
# Drive the Cisco IQ Link first-boot console wizard via vSphere USB scan codes (govc vm.keystrokes).
# Prompts pinned to IQ Link 1.3.0-v1.3.359 (boot_menu.py).
# Requires: govc >= 0.30, GOVC_URL/GOVC_USERNAME/GOVC_PASSWORD (+ GOVC_INSECURE if needed), nc.
# Optional: tesseract (OCR) for prompt detection; without it, a long boot wait plus fixed delays are used.
set -euo pipefail

: "${VM_NAME:?}" "${MGMT_IP_CIDR:?}" "${GATEWAY:?}" "${DNS_LIST:?}" "${NTP_LIST:?}" "${ADMIN_PASSWORD:?}"
SEARCH_DOMAIN="${SEARCH_DOMAIN:-}"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-admin}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-900}"
NO_OCR_BOOT_WAIT="${NO_OCR_BOOT_WAIT:-600}"
STEP_DELAY="${STEP_DELAY:-5}"
MGMT_IP="${MGMT_IP_CIDR%/*}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >&2; }

validate_password() {
  local p="$1"
  [[ ${#p} -ge 15 ]] || { log "password < 15 chars"; return 1; }
  [[ $(tr -cd 'A-Z' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 uppercase"; return 1; }
  [[ $(tr -cd 'a-z' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 lowercase"; return 1; }
  [[ $(tr -cd '0-9' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 digits"; return 1; }
  [[ $(tr -d 'A-Za-z0-9[:space:]' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 special chars"; return 1; }
  ! grep -qE '(.)\1' <<<"$p" || { log "repeated consecutive characters not allowed"; return 1; }
}

have_ocr() { command -v tesseract >/dev/null; }

screen_text() {
  have_ocr || return 1
  govc vm.console -capture "$WORKDIR/screen.png" "$VM_NAME" >/dev/null 2>&1 || return 1
  tesseract "$WORKDIR/screen.png" - 2>/dev/null
}

# Only the bottom of the screen holds the current prompt; earlier prompts stay visible above it.
current_prompt() { screen_text | grep -v '^[[:space:]]*$' | tail -n 3; }

# wait_for <regex> <timeout_s>
wait_for() {
  local pattern="$1" timeout="${2:-60}" waited=0
  if ! have_ocr; then sleep "$STEP_DELAY"; return 0; fi
  while (( waited < timeout )); do
    if current_prompt | grep -qiE "$pattern"; then return 0; fi
    sleep 5; waited=$((waited + 5))
  done
  log "timeout waiting for: $pattern"
  cp "$WORKDIR/screen.png" "./iqlink-day0-fail-$(date +%s).png" 2>/dev/null || true
  return 1
}

type_line() { # type text then Enter; empty string = just Enter
  if [[ -n "$1" ]]; then govc vm.keystrokes -vm "$VM_NAME" -s "$1"; fi
  govc vm.keystrokes -vm "$VM_NAME" -c KEY_ENTER
  sleep 1
}

validate_password "$ADMIN_PASSWORD"

log "Powering on $VM_NAME"
govc vm.info "$VM_NAME" | grep -qE 'Power state:[[:space:]]+poweredOn' || govc vm.power -on "$VM_NAME"

log "Waiting for login prompt"
if have_ocr; then
  wait_for 'login:' "$BOOT_TIMEOUT"
else
  log "tesseract not found; waiting ${NO_OCR_BOOT_WAIT}s for boot (no prompt detection)"
  sleep "$NO_OCR_BOOT_WAIT"
fi
type_line "admin"
wait_for 'Password' 30;                   type_line "$DEFAULT_PASSWORD"
wait_for 'Select a menu option' 120;      type_line "1"
wait_for 'IP Address/Mask' 60;            type_line "$MGMT_IP_CIDR"
wait_for 'Gateway' 30;                    type_line "$GATEWAY"
wait_for 'DNS IP' 30;                     type_line "$DNS_LIST"
wait_for 'Search Domain' 30;              type_line "$SEARCH_DOMAIN"
wait_for 'NTP Server' 30;                 type_line "$NTP_LIST"
wait_for 'frequency' 30;                  type_line "n"
wait_for 'NTP authentication' 30;         type_line "n"
wait_for 'New Password' 30;               type_line "$ADMIN_PASSWORD"
wait_for 'Confirm' 30;                    type_line "$ADMIN_PASSWORD"
wait_for 'Apply this network configuration' 60

if summary="$(screen_text)"; then
  grep -qF "$MGMT_IP" <<<"$summary" || { log "summary does not show $MGMT_IP; aborting (answering n)"; type_line "n"; exit 1; }
fi
type_line "Y"

log "Configuration submitted; waiting for appliance on $MGMT_IP (tcp 22/443)"
for _ in $(seq 1 60); do
  if nc -z -w 3 "$MGMT_IP" 443 2>/dev/null || nc -z -w 3 "$MGMT_IP" 22 2>/dev/null; then
    log "Appliance reachable"; exit 0
  fi
  sleep 10
done
log "Appliance not reachable after submit"; exit 1
