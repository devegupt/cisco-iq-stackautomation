#!/usr/bin/env bash
# iqlink_precheck.sh - fail fast before the OVA download / deploy.
# Env: MGMT_IP_CIDR, GATEWAY, DNS_LIST, NTP_LIST, ADMIN_PASSWORD, OVA_URL
#      REQUIRE_PTR (true|false, default false: warn only)
set -euo pipefail
: "${MGMT_IP_CIDR:?}" "${GATEWAY:?}" "${DNS_LIST:?}" "${NTP_LIST:?}" "${ADMIN_PASSWORD:?}" "${OVA_URL:?}"
REQUIRE_PTR="${REQUIRE_PTR:-false}"
IP="${MGMT_IP_CIDR%/*}"
FAIL=0

log()  { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
fail() { log "FAIL: $*"; FAIL=1; }
ok()   { log "OK:   $*"; }

# 1. Admin password policy (boot_constants.py / on-screen rules), checked before a 20+ minute deploy.
p="$ADMIN_PASSWORD"
[[ ${#p} -ge 15 ]]                                   || fail "admin password must be at least 15 characters"
[[ $(tr -cd 'A-Z' <<<"$p" | wc -c) -ge 2 ]]          || fail "admin password needs 2+ uppercase letters"
[[ $(tr -cd 'a-z' <<<"$p" | wc -c) -ge 2 ]]          || fail "admin password needs 2+ lowercase letters"
[[ $(tr -cd '0-9' <<<"$p" | wc -c) -ge 2 ]]          || fail "admin password needs 2+ digits"
[[ $(tr -d 'A-Za-z0-9[:space:]' <<<"$p" | wc -c) -ge 2 ]] || fail "admin password needs 2+ special characters"
grep -qE '(.)\1' <<<"$p"                             && fail "admin password must not repeat a character consecutively"
LC_ALL=C grep -q '[^!-~]' <<<"$p"                    && fail "admin password: use printable US-keyboard ASCII without spaces (typed as keystrokes)"
(( FAIL == 0 )) && ok "admin password meets the IQ Link policy"

# 2. Gateway inside the management subnet.
python3 - "$MGMT_IP_CIDR" "$GATEWAY" <<'PY' && ok "gateway $GATEWAY is inside $MGMT_IP_CIDR" || fail "gateway $GATEWAY is not inside $MGMT_IP_CIDR"
import ipaddress, sys
net = ipaddress.ip_interface(sys.argv[1]).network
sys.exit(0 if ipaddress.ip_address(sys.argv[2]) in net else 1)
PY

# 3. Management IP must be free (IQ Link does not support DHCP; a clash breaks Day 0).
if ping -c 2 -W 2 "$IP" >/dev/null 2>&1 || curl -sk --noproxy "$IP" --connect-timeout 3 --max-time 5 -o /dev/null "https://$IP/"; then
  fail "$IP already answers (ping or HTTPS) - choose a free address or remove the old VM"
else
  ok "$IP does not answer - looks free"
fi

# 4. Reverse DNS (PTR) - required by IQ Link (getting started guide).
if name=$(python3 -c 'import socket,sys; print(socket.gethostbyaddr(sys.argv[1])[0])' "$IP" 2>/dev/null); then
  ok "reverse DNS: $IP -> $name"
  python3 -c 'import socket,sys; sys.exit(0 if sys.argv[2] in socket.gethostbyname_ex(sys.argv[1])[2] else 1)' "$name" "$IP" 2>/dev/null \
    && ok "forward DNS: $name -> $IP" || log "WARN: forward lookup of $name does not return $IP (as seen from the management server)"
  [[ "$name" == "$(tr 'A-Z' 'a-z' <<<"$name")" ]] || log "WARN: hostname $name is not lowercase (IQ Link requires lowercase FQDNs)"
else
  if [[ "$REQUIRE_PTR" == "true" ]]; then fail "no reverse DNS (PTR) record for $IP"
  else log "WARN: no reverse DNS (PTR) record for $IP as seen from the management server (required by IQ Link)"; fi
fi

# 5. OVA reachable from the management server (the original failure mode in the DMZ lab).
code=$(curl -sIL -o /dev/null -w '%{http_code}' --connect-timeout 15 --max-time 60 "$OVA_URL" || echo 000)
size=$(curl -sIL --connect-timeout 15 --max-time 60 "$OVA_URL" | awk 'tolower($1)=="content-length:"{v=$2} END{gsub("\r","",v); print v}')
if [[ "$code" == 200 ]]; then ok "OVA reachable (HTTP 200, ${size:-unknown} bytes): $(basename "${OVA_URL%%\?*}")"
else fail "OVA URL not reachable from the management server (HTTP $code): $OVA_URL"; fi

if (( FAIL )); then log "Precheck failed - nothing was deployed."; exit 1; fi
log "Precheck passed."
