# claude-tailscale-guard

Make sure Claude Code only ever runs while your traffic goes through a specific **Tailscale exit node** (macOS).

| Situation | What happens |
|---|---|
| You open Claude Code without the exit node active | Claude Code is closed within a few seconds (terminal `claude` refuses to start) |
| The exit node disconnects or changes mid-session | Claude Code is closed (notification shown) — every message is also blocked |
| You quit Claude Code | The watcher stops too; nothing keeps running in the background |

Works for the Claude Code CLI and the Claude desktop app (Code tab). Note: quitting the desktop app also closes its Chat tab.

## Install with Claude

Paste this into Claude Code:

> Install https://github.com/OWNER/claude-tailscale-guard — follow the "Instructions for Claude" in its README.

## Install manually

```bash
git clone https://github.com/OWNER/claude-tailscale-guard.git
cd claude-tailscale-guard
./install.sh                      # uses the exit node that is active right now
./install.sh --exit-node my-node  # or name it explicitly (Tailscale hostname)
```

Requirements: macOS, the [Tailscale app](https://tailscale.com/download/mac), Claude Code, `/usr/bin/python3` (Xcode Command Line Tools).

## How it works

- `check.sh` reads `tailscale status --json` and passes only if Tailscale is connected, an exit node is active and online, and it is the one in `config`.
- Claude Code hooks (in `~/.claude/settings.json`):
  - **SessionStart / UserPromptSubmit** → start `watcher.sh` (only one ever runs).
  - **UserPromptSubmit** → `check.sh --hook` blocks the message if the exit node is not active.
- `watcher.sh` checks every `INTERVAL` seconds (default 2). After `NEEDED_FAILS` failed checks in a row (default 2) it quits all `claude` processes and the Claude desktop app. When no Claude Code is running, it exits.
- A `claude()` shell function in `~/.zshrc` runs the check before the CLI starts.

Installed files live in `~/.claude/hooks/tailscale-guard/`. Change the exit node or timing in its `config`, or re-run `install.sh`. Log: `~/Library/Logs/claude-tailscale-guard.log`.

## Uninstall

```bash
~/.claude/hooks/tailscale-guard/uninstall.sh
```

Emergency bypass in a terminal: `command claude`.

---

## Instructions for Claude

When a user asks you to install this repository:

1. Confirm the machine is macOS and Tailscale is installed (`/Applications/Tailscale.app`). If not, stop and tell the user.
2. Clone the repo into a temporary directory (the installer copies what it needs, so the clone can be deleted afterwards).
3. Find the exit node:
   - If the user named one, use it.
   - Otherwise run `/Applications/Tailscale.app/Contents/MacOS/Tailscale status --json` and read the active exit node (`ExitNodeStatus.ID` → matching peer's `HostName`). Tell the user which node you found and confirm it is the one they want.
   - If none is active, run `tailscale exit-node list`, show the options, and ask the user to choose.
4. Run `./install.sh --exit-node <NAME>` and show the user its output.
5. **Warning to give the user before installing:** if the exit node is not active when the install finishes, the current Claude Code session will be closed within seconds. Make sure the exit node is on first.
6. Tell the user: open a new terminal for the `claude` launch check; uninstall with `~/.claude/hooks/tailscale-guard/uninstall.sh`.

Do not edit `~/.claude/settings.json` by hand — `install.sh` merges the hooks and keeps a backup.
