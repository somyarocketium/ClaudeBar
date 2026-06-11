# ClaudeBar

A lightweight macOS menu bar app that keeps an eye on your [Claude Code](https://claude.com/claude-code) sessions and plan usage — so you don't have to keep switching back to the terminal.

## Features

- **Live session tracking** — see every running Claude Code session at a glance: working directory, PID, model, and elapsed time. The menu bar icon shows a count badge when sessions are active.
- **Plan usage meters** — 5-hour and 7-day rate-limit windows with color-coded progress bars (green → orange → red) and reset countdowns, sourced from Claude Code's own statusline payload.
- **Daily cost & tokens** — today's spend and token usage via [ccusage](https://github.com/ryoppippi/ccusage).
- **Session-finished notifications** — get a macOS notification when a Claude Code session ends, either via the bundled Stop hook or the app's built-in process watcher.
- **Native and tiny** — pure Swift/SwiftUI, no Electron, no dock icon, no background daemons. Polls `ps` every 3 seconds and `ccusage` every minute.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`) — for building from source
- [Claude Code](https://claude.com/claude-code) — the thing being monitored
- [ccusage](https://github.com/ryoppippi/ccusage) (optional) — for daily cost/token stats: `npm i -g ccusage`
- `jq` (optional) — used by the bundled statusline script: `brew install jq`

## Installation

### Build from source

```bash
git clone https://github.com/somyarocketium/ClaudeBar.git
cd ClaudeBar
./build.sh
```

This compiles a release binary, assembles `~/Applications/ClaudeBar.app`, and ad-hoc signs it. Then launch it:

```bash
open ~/Applications/ClaudeBar.app
```

To launch it at login: **System Settings → General → Login Items → +** and add ClaudeBar.

### First launch

The app lives entirely in the menu bar (look for the four-petal sparkle ✦). Session tracking works immediately. Plan usage meters need one extra step — see below.

## Claude Code integration

ClaudeBar gets richer with two optional Claude Code hooks. Both scripts live in [`scripts/`](scripts/).

### 1. Plan usage meters (statusline)

Claude Code sends a JSON payload (including `rate_limits`) to your configured statusline command on every update. The bundled script captures that payload to `~/.claude/last-status.json` — which ClaudeBar reads — and also renders a nice colored statusline in your terminal:

```
Opus 4.8 │ ~/dev/myproject main● │ 5h ▰▰▱▱▱▱▱▱▱▱ 25% │ 7d ▰▱▱▱▱▱▱▱▱▱ 12%
```

Install it:

```bash
cp scripts/statusline-bar.sh ~/.claude/statusline-bar.sh
chmod +x ~/.claude/statusline-bar.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline-bar.sh"
  }
}
```

> **Note:** rate-limit data only flows while a Claude Code session is running — the same constraint as Claude Code's own `/usage` command. When idle, ClaudeBar shows the last known values.

### 2. Session-finished notifications (Stop hook)

For an instant notification the moment Claude finishes responding (rather than when the process exits):

```bash
cp scripts/hook-stop.sh ~/.claude/hook-stop.sh
chmod +x ~/.claude/hook-stop.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "~/.claude/hook-stop.sh" }
        ]
      }
    ]
  }
}
```

## How it works

| Component | What it does |
|---|---|
| `ProcessMonitor` | Polls `ps` every 3s for Claude Code processes; resolves each session's working directory via `lsof` and detects finished sessions by PID diffing. |
| `UsageMonitor` | Reads `~/.claude/last-status.json` for rate-limit windows; shells out to `ccusage blocks` / `ccusage daily` for cost and token stats. |
| `MenuContent` | The SwiftUI popover: status header, session list, plan usage bars, refresh/quit footer. |
| `ClaudeBarApp` | `MenuBarExtra` entry point with a hand-rendered template icon (adapts to light/dark menu bars). |

There is no network access, no telemetry, and nothing leaves your machine — the app only reads local process info and files under `~/.claude/`.

## Development

```bash
swift build            # debug build
swift run ClaudeBar    # run directly (menu bar item appears)
./build.sh             # release build + .app bundle
```

## Troubleshooting

- **"ccusage not installed" in the menu** — `npm i -g ccusage`, then click Refresh. Daily cost/tokens are optional; sessions and plan meters work without it.
- **Plan usage says "waiting for session"** — the statusline script isn't installed or no Claude Code session has run since. See [integration](#claude-code-integration) above.
- **No sessions listed while Claude is running** — the process matcher looks for standard Claude Code install paths (`~/.local/bin/claude`, `~/.local/share/claude/versions`, npm `claude-code/<version>`). If you run Claude from a nonstandard path, open an issue with the output of `ps -axo pid,command | grep claude`.

## License

[MIT](LICENSE)
