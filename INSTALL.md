# Installing claude-tailscale-guard — instructions for Claude

You are Claude Code, and the user asked you to install this repository. Follow these steps in order. Talk to the user in the language they used.

**What this installs:** hooks and a small watcher that close Claude Code whenever the user's chosen Tailscale exit node is not active. That includes the session you are running in right now. Get step 3 right before you run the installer.

## 1. Check requirements

Run these and stop if any fail. Tell the user what is missing and how to fix it.

```bash
uname                                                     # must be Darwin (macOS only)
ls /Applications/Tailscale.app/Contents/MacOS/Tailscale   # Tailscale app installed
/usr/bin/python3 --version                                # if missing: xcode-select --install
```

## 2. Get the code

Clone into a new temporary directory. The installer copies what it needs, so the clone can be deleted afterwards.

```bash
DIR="$(mktemp -d)" && git clone --depth 1 https://github.com/arneanne/claude-tailscale-guard.git "$DIR/claude-tailscale-guard"
```

## 3. Choose the exit node — confirm with the user

The exit node is the Tailscale **hostname** of the machine all traffic must go through.

- If the user already named one, use it.
- Otherwise read the active one:
  ```bash
  /Applications/Tailscale.app/Contents/MacOS/Tailscale status --json | /usr/bin/python3 -c '
  import json,sys; d=json.load(sys.stdin); st=d.get("ExitNodeStatus") or {}
  p=next((p for p in (d.get("Peer") or {}).values() if p.get("ID")==st.get("ID")),{})
  print(p.get("HostName","(none active)"), "| online:", st.get("Online"))'
  ```
  Tell the user which node is active and **ask them to confirm** it is the one Claude Code must require.
- If none is active, list the choices with `/Applications/Tailscale.app/Contents/MacOS/Tailscale exit-node list`. Ask the user to pick one **and turn it on in the Tailscale menu** before you continue.

Before installing, tell the user plainly:

> Once this is installed, Claude Code, including this session, closes within a few seconds whenever exit node `<NAME>` is not active. It's active right now, so this session will keep running.

Do not continue until the chosen exit node is active. Otherwise the install closes this session.

## 4. Install

```bash
"$DIR/claude-tailscale-guard/install.sh" --exit-node <NAME>
```

Show the user the output. The installer:
- copies the scripts to `~/.claude/hooks/tailscale-guard/` and writes `config` there;
- adds the hooks to `~/.claude/settings.json`, keeping a backup and the user's other settings;
- adds a `claude()` launch check to `~/.zshrc` (and `~/.bashrc` if it exists). Skip this with `--no-shell-wrapper` if the user doesn't want it.

Do **not** edit `~/.claude/settings.json` by hand, and do not run anything with `sudo`.

## 5. Verify

```bash
~/.claude/hooks/tailscale-guard/check.sh && echo "check OK"
grep -c tailscale-guard ~/.claude/settings.json             # expect 3
~/.claude/hooks/tailscale-guard/watcher.sh --start
cat "/tmp/claude-tailscale-guard.$(id -u).lock"              # PID of the running watcher
```

If `check.sh` fails, show its message. It says exactly what is wrong (Tailscale off, no exit node, wrong node, node offline).

## 6. Tell the user

- It's installed and protecting Claude Code with exit node `<NAME>`.
- Open a new terminal (or run `source ~/.zshrc`) so the `claude` launch check applies.
- To test it: turn the exit node off. Claude Code closes within about 5 seconds and a notification appears.
- Change the node or timing: edit `~/.claude/hooks/tailscale-guard/config`, or re-run `install.sh --exit-node NEW`.
- Log: `~/Library/Logs/claude-tailscale-guard.log`
- Uninstall: `~/.claude/hooks/tailscale-guard/uninstall.sh`
- Emergency bypass in a terminal: `command claude`
- The temporary clone in `$DIR` can be deleted.
