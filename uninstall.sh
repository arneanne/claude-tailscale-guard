#!/bin/bash
# Remove claude-tailscale-guard: hooks, shell wrapper, watcher and installed files.
set -euo pipefail

GUARD_DIR="$HOME/.claude/hooks/tailscale-guard"
SETTINGS="$HOME/.claude/settings.json"
SRC="$(cd "$(dirname "$0")" && pwd)"
BEGIN="# >>> claude-tailscale-guard >>>"
END="# <<< claude-tailscale-guard <<<"

[ -x "$GUARD_DIR/watcher.sh" ] && "$GUARD_DIR/watcher.sh" --stop || true

settings_py="$GUARD_DIR/settings.py"
[ -f "$settings_py" ] || settings_py="$SRC/lib/settings.py"
if [ -f "$SETTINGS" ]; then
  cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d%H%M%S)"
  /usr/bin/python3 "$settings_py" remove "$SETTINGS" "$GUARD_DIR"
  echo "→ Removed hooks from $SETTINGS"
fi

for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
  [ -f "$rc" ] && grep -q "^$BEGIN\$" "$rc" || continue
  sed -i '' "/^$BEGIN\$/,/^$END\$/d" "$rc"
  echo "→ Removed launch check from $rc"
done

rm -rf "$GUARD_DIR"
echo "✓ Uninstalled. Open a new terminal (or run: unset -f claude) to drop the launch check from this shell."
