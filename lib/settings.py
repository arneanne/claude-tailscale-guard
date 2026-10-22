"""Add or remove the tailscale-guard hooks in a Claude Code settings.json.

usage: python3 settings.py add|remove <settings.json> <guard_dir>
Leaves every other setting and hook untouched. Idempotent.
"""
import json
import os
import sys

# Commands from this project (current and earlier layouts) that `add` replaces and `remove` deletes.
MARKERS = ("tailscale-guard/", "check-tailscale.sh", "tailscale-watcher.sh")


def ours(hook):
    return any(m in hook.get("command", "") for m in MARKERS)


def strip(settings):
    hooks = settings.get("hooks", {})
    for event in list(hooks):
        groups = []
        for group in hooks[event]:
            kept = [h for h in group.get("hooks", []) if not ours(h)]
            if kept:
                groups.append({**group, "hooks": kept})
        if groups:
            hooks[event] = groups
        else:
            del hooks[event]
    if not hooks:
        settings.pop("hooks", None)


def add(settings, guard_dir):
    start = {"type": "command", "command": f'"{guard_dir}/watcher.sh" --start', "timeout": 10}
    check = {"type": "command", "command": f'"{guard_dir}/check.sh" --hook', "timeout": 10}
    hooks = settings.setdefault("hooks", {})
    hooks.setdefault("SessionStart", []).append({"hooks": [start]})
    hooks.setdefault("UserPromptSubmit", []).append({"hooks": [start, check]})


def main():
    action, path, guard_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    settings = {}
    if os.path.exists(path):
        with open(path) as f:
            text = f.read().strip()
        settings = json.loads(text) if text else {}
    strip(settings)
    if action == "add":
        add(settings, guard_dir)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(settings, f, indent=2, ensure_ascii=False)
        f.write("\n")


if __name__ == "__main__":
    main()
