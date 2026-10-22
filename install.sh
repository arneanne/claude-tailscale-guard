#!/bin/bash
# Install claude-tailscale-guard: Claude Code only runs while a chosen Tailscale exit node is active.
#
#   ./install.sh                         use the exit node that is active right now
#   ./install.sh --exit-node NAME        use this exit node (Tailscale hostname)
#   ./install.sh --no-shell-wrapper      don't add the `claude` launch check to ~/.zshrc / ~/.bashrc
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
GUARD_DIR="$HOME/.claude/hooks/tailscale-guard"
SETTINGS="$HOME/.claude/settings.json"
TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
BEGIN="# >>> claude-tailscale-guard >>>"
END="# <<< claude-tailscale-guard <<<"

exit_node=""
shell_wrapper=1
while [ $# -gt 0 ]; do
  case "$1" in
    --exit-node) exit_node="${2:?--exit-node needs a name}"; shift 2 ;;
    --no-shell-wrapper) shell_wrapper=0; shift ;;
    -h|--help) sed -n '2,7p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 1 ;;
  esac
done

die() { echo "✗ $*" >&2; exit 1; }

[ "$(uname)" = "Darwin" ] || die "macOS only."
[ -x /usr/bin/python3 ] || die "/usr/bin/python3 not found (install Xcode Command Line Tools: xcode-select --install)."
[ -x "$TS" ] || TS="$(command -v tailscale || true)"
[ -n "$TS" ] || die "Tailscale not found. Install the Tailscale app first."

# Default to the exit node that is active right now.
if [ -z "$exit_node" ]; then
  exit_node="$("$TS" status --json 2>/dev/null | /usr/bin/python3 -c '
import json, sys
d = json.load(sys.stdin)
st = d.get("ExitNodeStatus") or {}
peer = next((p for p in (d.get("Peer") or {}).values() if p.get("ID") == st.get("ID")), None)
print((peer or {}).get("HostName", ""))
' 2>/dev/null || true)"
  [ -n "$exit_node" ] || die "No exit node is active. Turn one on, or pass --exit-node NAME.
  Available exit nodes:
$("$TS" exit-node list 2>/dev/null | sed 's/^/    /')"
fi

echo "→ Installing to $GUARD_DIR (exit node: $exit_node)"
mkdir -p "$GUARD_DIR"
"$GUARD_DIR/watcher.sh" --stop 2>/dev/null || true
install -m 755 "$SRC/bin/check.sh" "$SRC/bin/watcher.sh" "$SRC/uninstall.sh" "$GUARD_DIR/"
install -m 644 "$SRC/lib/settings.py" "$GUARD_DIR/"
cat > "$GUARD_DIR/config" <<EOF
# claude-tailscale-guard settings (re-run install.sh or edit this file)
EXIT_NODE="$exit_node"   # Tailscale hostname of the required exit node
INTERVAL=2               # seconds between checks while Claude Code is running
NEEDED_FAILS=2           # consecutive failed checks before Claude Code is closed
EOF

echo "→ Adding hooks to $SETTINGS"
[ -f "$SETTINGS" ] && cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
/usr/bin/python3 "$GUARD_DIR/settings.py" add "$SETTINGS" "$GUARD_DIR"

if [ "$shell_wrapper" = 1 ]; then
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [ "$rc" = "$HOME/.zshrc" ] || [ -f "$rc" ] || continue
    touch "$rc"
    sed -i '' "/^$BEGIN\$/,/^$END\$/d" "$rc"
    cat >> "$rc" <<EOF
$BEGIN
claude() {
  "$GUARD_DIR/check.sh" || return 1
  command claude "\$@"
}
$END
EOF
    echo "→ Added launch check to $rc"
  done
fi

echo
if "$GUARD_DIR/check.sh"; then
  echo "✓ Installed. Exit node '$exit_node' is active right now, so Claude Code is allowed."
else
  echo "✓ Installed. (The check above fails right now, so Claude Code will be closed until '$exit_node' is active.)"
fi
echo "  Open a new terminal (or: source ~/.zshrc) for the launch check. Log: ~/Library/Logs/claude-tailscale-guard.log"
echo "  Uninstall: $GUARD_DIR/uninstall.sh"
