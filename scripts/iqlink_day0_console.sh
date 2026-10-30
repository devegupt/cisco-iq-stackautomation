#!/usr/bin/env bash
# Drive the Cisco IQ Link first-boot console wizard via vSphere USB scan codes (govc vm.keystrokes).
# OCR patterns tolerate tesseract dropping the first character at the screen edge
# (e.g. 'assword', 'elect a menu option') - tested on screenshots/02-console-day0/.
# Prompt sequence verified against IQ Link 1.3.0-v1.3.359 screenshots (screenshots/02-console-day0/)
# and the boot-menu source. 1.2.x builds before 2026-08-25 do not ask the NTP clock-comparison
# frequency question; NTP_POLL_PROMPT controls that (auto = detect with OCR).
#
# Required env: VM_NAME (name or full inventory path), MGMT_IP_CIDR, GATEWAY, DNS_LIST, NTP_LIST,
#               ADMIN_PASSWORD, GOVC_URL/GOVC_USERNAME/GOVC_PASSWORD (+ GOVC_INSECURE)
# Optional env: SEARCH_DOMAIN, DEFAULT_PASSWORD (admin), BOOT_TIMEOUT (900), NO_OCR_BOOT_WAIT (600),
#               STEP_DELAY (5), NTP_POLL_PROMPT (auto|yes|no), GOVC (govc binary path)
# Tools: govc >= 0.30, nc or curl; tesseract strongly recommended (prompt detection).
set -euo pipefail

: "${VM_NAME:?}" "${MGMT_IP_CIDR:?}" "${GATEWAY:?}" "${DNS_LIST:?}" "${NTP_LIST:?}" "${ADMIN_PASSWORD:?}"
SEARCH_DOMAIN="${SEARCH_DOMAIN:-}"
DEFAULT_PASSWORD="${DEFAULT_PASSWORD:-admin}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-900}"
NO_OCR_BOOT_WAIT="${NO_OCR_BOOT_WAIT:-600}"
STEP_DELAY="${STEP_DELAY:-5}"
NTP_POLL_PROMPT="${NTP_POLL_PROMPT:-auto}"
GOVC="${GOVC:-govc}"
MGMT_IP="${MGMT_IP_CIDR%/*}"
WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*" >&2; }

validate_password() {
  local p="$1"
  [[ ${#p} -ge 15 ]] || { log "password < 15 chars"; return 1; }
  [[ $(tr -cd 'A-Z' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 uppercase"; return 1; }
  [[ $(tr -cd 'a-z' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 lowercase"; return 1; }
  [[ $(tr -cd '0-9' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 digits"; return 1; }
  [[ $(tr -d 'A-Za-z0-9[:space:]' <<<"$p" | wc -c) -ge 2 ]] || { log "need >= 2 special chars"; return 1; }
  ! grep -qE '(.)\1' <<<"$p" || { log "repeated consecutive characters not allowed"; return 1; }
  LC_ALL=C grep -q '[^ -~]' <<<"$p" && { log "use US-keyboard printable ASCII only"; return 1; }
  return 0
}

have_ocr() { command -v tesseract >/dev/null; }

screen_text() {
  have_ocr || return 1
  "$GOVC" vm.console -capture "$WORKDIR/screen.png" "$VM_NAME" >/dev/null 2>&1 || return 1
  tesseract "$WORKDIR/screen.png" - 2>/dev/null
}

# The current prompt is at the bottom; earlier prompts stay visible above it.
current_prompt() { screen_text | grep -v '^[[:space:]]*$' | tail -n 3; }

save_failure_screen() {
  local out="./iqlink-day0-fail-$(date +%s).png"
  "$GOVC" vm.console -capture "$out" "$VM_NAME" >/dev/null 2>&1 && log "console screenshot saved: $out"
}

# wait_for <regex> <timeout_s>
wait_for() {
  local pattern="$1" timeout="${2:-60}" waited=0
  if ! have_ocr; then sleep "$STEP_DELAY"; return 0; fi
  while (( waited < timeout )); do
    if current_prompt | grep -qiE "$pattern"; then return 0; fi
    sleep 5; waited=$((waited + 5))
  done
  log "timeout waiting for: $pattern"
  save_failure_screen
  return 1
}

type_line() { # type text then Enter; empty string = just Enter
  if [[ -n "$1" ]]; then "$GOVC" vm.keystrokes -vm "$VM_NAME" -s "$1"; fi
  "$GOVC" vm.keystrokes -vm "$VM_NAME" -c KEY_ENTER
  sleep 1
}

port_open() {
  if command -v nc >/dev/null; then nc -z -w 3 "$1" "$2" 2>/dev/null
  else curl -sk --connect-timeout 3 -o /dev/null "telnet://$1:$2" 2>/dev/null; fi
}

validate_password "$ADMIN_PASSWORD"
have_ocr || log "WARNING: tesseract not found; using fixed delays (less reliable). NTP_POLL_PROMPT=$NTP_POLL_PROMPT"
if ! have_ocr && [[ "$NTP_POLL_PROMPT" == "auto" ]]; then
  log "ERROR: NTP_POLL_PROMPT=auto needs OCR; set yes (1.3.x) or no (1.2.x)"; exit 1
fi

log "VM: $VM_NAME  IP: $MGMT_IP_CIDR  GW: $GATEWAY  DNS: $DNS_LIST  NTP: $NTP_LIST  domain: ${SEARCH_DOMAIN:-<default>}"
"$GOVC" vm.info "$VM_NAME" | grep -qE 'Power state:[[:space:]]+poweredOn' || { log "Powering on"; "$GOVC" vm.power -on "$VM_NAME"; }

log "Waiting for login prompt (up to ${BOOT_TIMEOUT}s)"
if have_ocr; then
  wait_for 'ogin:' "$BOOT_TIMEOUT"
else
  sleep "$NO_OCR_BOOT_WAIT"
fi
type_line "admin"
wait_for 'assword' 30;                    type_line "$DEFAULT_PASSWORD"
wait_for 'menu option' 120;                 type_line "1"
wait_for 'Address/Mask|192\.168\.1' 60;      type_line "$MGMT_IP_CIDR"
wait_for 'ateway' 30;                     type_line "$GATEWAY"
wait_for 'DNS' 30;                        type_line "$DNS_LIST"
wait_for 'earch Domain|local\.domain' 30; type_line "$SEARCH_DOMAIN"
wait_for 'erver List|pool\.ntp' 30;      type_line "$NTP_LIST"

# 1.3.x asks for NTP poll frequency first; 1.2.x goes straight to NTP authentication.
case "$NTP_POLL_PROMPT" in
  yes) wait_for 'frequency' 30; type_line "n" ;;
  no)  : ;;
  auto)
    wait_for 'frequency|authentication' 30
    if current_prompt | grep -qi 'frequency'; then log "NTP poll-frequency prompt present"; type_line "n"; fi ;;
esac
wait_for 'authentication' 30;           type_line "n"
wait_for 'ew Password' 30;                type_line "$ADMIN_PASSWORD"
wait_for 'onfirm' 30;                     type_line "$ADMIN_PASSWORD"
wait_for 'Apply this|configuration\?' 60

# OCR misreads digits (e.g. 10.122.226.150 -> "19. 122.226. 158"), so the summary check only warns.
if summary="$(screen_text)"; then
  if tr -d ' ' <<<"$summary" | grep -qF "$MGMT_IP"; then log "summary shows $MGMT_IP"
  else log "WARNING: could not read $MGMT_IP in the summary via OCR (values were typed as given)"; save_failure_screen; fi
fi
type_line "Y"

log "Configuration submitted; waiting for $MGMT_IP (tcp 443/22)"
for _ in $(seq 1 90); do
  if port_open "$MGMT_IP" 443 || port_open "$MGMT_IP" 22; then
    log "Appliance reachable on $MGMT_IP"
    echo "mgmt_ip=$MGMT_IP"
    exit 0
  fi
  sleep 10
done
log "Appliance not reachable 15 min after submit"
save_failure_screen
exit 1
