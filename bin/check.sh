#!/bin/bash
# Verify that Tailscale is connected AND routing through the required exit node.
#   check.sh          -> exit 0 if OK, 1 if not (used by the `claude` shell wrapper)
#   check.sh --hook   -> exit 0 if OK, 2 if not (Claude Code hook: exit 2 blocks the prompt)

GUARD_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
[ -f "$GUARD_DIR/config" ] && . "$GUARD_DIR/config"
REQUIRED_EXIT_NODE="${GUARD_EXIT_NODE:-$EXIT_NODE}"

TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
[ -x "$TS" ] || TS="$(command -v tailscale)"

fail_code=1
[ "$1" = "--hook" ] && fail_code=2

fail() {
  echo "🚫 Blocked: $1" >&2
  echo "   Turn on Tailscale and select exit node '$REQUIRED_EXIT_NODE', then try again." >&2
  exit "$fail_code"
}

[ -n "$REQUIRED_EXIT_NODE" ] || fail "no EXIT_NODE set in $GUARD_DIR/config."
[ -n "$TS" ] || fail "Tailscale CLI not found."

json="$("$TS" status --json 2>/dev/null)" || fail "Tailscale is not running."

reason="$(printf '%s' "$json" | /usr/bin/python3 -c '
import json, sys
want = sys.argv[1].lower()
try:
    d = json.load(sys.stdin)
except Exception:
    print("could not read Tailscale status."); sys.exit()
if d.get("BackendState") != "Running":
    print("Tailscale is not connected (state: %s)." % d.get("BackendState")); sys.exit()
st = d.get("ExitNodeStatus")
if not st:
    print("no exit node is active."); sys.exit()
if not st.get("Online"):
    print("the exit node is offline."); sys.exit()
peer = next((p for p in (d.get("Peer") or {}).values() if p.get("ID") == st.get("ID")), None)
name = (peer or {}).get("HostName", "?")
dns = (peer or {}).get("DNSName", "").split(".")[0]
if want not in (name.lower(), dns.lower()):
    print("wrong exit node active (%s)." % name)
' "$REQUIRED_EXIT_NODE")"

[ -z "$reason" ] || fail "$reason"
exit 0
