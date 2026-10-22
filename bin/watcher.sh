#!/bin/bash
# Session-scoped Tailscale guard for Claude Code.
#   watcher.sh --start   Launch the watcher in the background (no-op if one is already running).
#                        Called by the Claude Code SessionStart / UserPromptSubmit hooks.
#   watcher.sh --run     The watcher loop itself. Every INTERVAL seconds:
#                        - no Claude Code left running   -> exit (watcher shuts itself down)
#                        - exit node check fails N times -> quit Claude Code (CLI sessions + desktop app)
#   DRY_RUN=1            Only log what would be killed.

GUARD_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=/dev/null
[ -f "$GUARD_DIR/config" ] && . "$GUARD_DIR/config"

CHECK="${WATCH_CHECK:-$GUARD_DIR/check.sh}"
LOG="$HOME/Library/Logs/claude-tailscale-guard.log"
LOCK="${WATCHER_LOCK:-/tmp/claude-tailscale-guard.$(id -u).lock}"
PROC_NAME="${WATCH_PROC:-claude}"
APP_BIN="${WATCH_APP:-/Applications/Claude.app/Contents/MacOS/Claude}"
INTERVAL="${WATCH_INTERVAL:-${INTERVAL:-2}}"
NEEDED_FAILS="${NEEDED_FAILS:-2}"

log() { echo "$(date '+%F %T') [$$] $*" >> "$LOG"; }
app_pid() { ps -axo pid=,comm= | awk -v b="$APP_BIN" '$2==b{print $1}'; }
cli_pids() { pgrep -x "$PROC_NAME"; }

watcher_alive() {
  local pid; pid="$(cat "$LOCK" 2>/dev/null)"
  [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null
}

case "$1" in
  --start)
    watcher_alive && exit 0
    nohup /bin/bash "$0" --run </dev/null >/dev/null 2>&1 &
    exit 0
    ;;
  --stop)
    watcher_alive && kill "$(cat "$LOCK")"
    exit 0
    ;;
  --run) ;;
  *) echo "usage: $0 --start | --stop | --run" >&2; exit 1 ;;
esac

# Singleton: claim the lock, or leave if another watcher got there first.
watcher_alive && exit 0
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT
log "watcher started"

fails=0
while :; do
  claude_pids="$(cli_pids)"
  app_running="$(app_pid)"
  if [ -z "$claude_pids" ] && [ -z "$app_running" ]; then
    log "Claude Code is no longer running -> watcher exiting"
    exit 0
  fi

  if reason="$("$CHECK" 2>&1)"; then
    fails=0
  else
    fails=$((fails + 1))
    if [ "$fails" -ge "$NEEDED_FAILS" ]; then
      msg="$(printf '%s' "$reason" | head -1)"
      log "$msg -> quitting Claude Code (pids: $(echo $claude_pids) app: ${app_running:-no})"
      if [ -n "$DRY_RUN" ]; then
        log "DRY_RUN: nothing killed"
      else
        /usr/bin/osascript -e "display notification \"$msg\" with title \"Claude Code closed\" subtitle \"Tailscale exit node required\"" >/dev/null 2>&1
        [ -n "$claude_pids" ] && kill -TERM $claude_pids 2>/dev/null
        [ -n "$app_running" ] && /usr/bin/osascript -e 'quit app "Claude"' >/dev/null 2>&1
        sleep 5
        left="$(cli_pids) $(app_pid)"; [ -n "${left// }" ] && kill -KILL $left 2>/dev/null
      fi
      fails=0
    fi
  fi
  sleep "$INTERVAL"
done
