# claude-tailscale-guard

Make sure Claude Code only ever runs while your traffic goes through a specific **Tailscale exit node** (macOS).

| Situation | What happens |
|---|---|
| You open Claude Code without the exit node active | Claude Code is closed within a few seconds (terminal `claude` refuses to start) |
| The exit node disconnects or changes mid-session | Claude Code is closed (notification shown) — every message is also blocked |
| You quit Claude Code | The watcher stops too; nothing keeps running in the background |

Works for the Claude Code CLI and the Claude desktop app (Code tab). Note: quitting the desktop app also closes its Chat tab.

## Install with Claude

Turn on your Tailscale exit node first, then paste this into Claude Code:

```text
Install claude-tailscale-guard from https://github.com/arneanne/claude-tailscale-guard.
Clone it to a temporary folder, read its INSTALL.md, and follow every step in order.
Confirm the exit node with me before running the installer.
```

中文：

```text
请从 https://github.com/arneanne/claude-tailscale-guard 安装 claude-tailscale-guard。
把它克隆到临时文件夹，阅读其中的 INSTALL.md，并按顺序完成每一步。
运行安装脚本之前，先和我确认要使用的 exit node。
```

Claude checks your Mac, finds your active exit node, confirms it with you, installs, and verifies. Full steps: [INSTALL.md](INSTALL.md).

## Install manually

```bash
git clone https://github.com/arneanne/claude-tailscale-guard.git
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
