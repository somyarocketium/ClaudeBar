# Architecture

ClaudeBar is a single-target Swift Package (no Xcode project) producing a menu-bar-only app. Everything lives in `Sources/ClaudeBar/`.

```
┌─────────────────────────────────────────────┐
│ ClaudeBarApp (MenuBarExtra)                 │
│  ├─ MenuBarLabel    sparkle icon + count    │
│  └─ MenuContent     popover UI              │
│       ├─ ProcessMonitor  (3s timer)         │
│       └─ UsageMonitor    (60s timer)        │
└─────────────────────────────────────────────┘
            │                    │
            ▼                    ▼
   ps / lsof (local)    ~/.claude/last-status.json
                        ccusage blocks / daily
```

## Data sources

### Session list — `ProcessMonitor.swift`

Every 3 seconds, runs `ps -axo pid,etime,command` filtered to Claude Code install patterns (`claude-code/<version>`, `~/.local/share/claude/versions`, `~/.local/bin/claude`), excluding the Claude desktop app and its helpers. For each PID it resolves the working directory with `lsof -p <pid> -d cwd` and parses `--model` from the command line if present.

Finished-session detection is a PID-set diff between polls: any PID present last time but gone now triggers the `onSessionFinished` callback, which posts a `UserNotifications` alert. (The Stop hook in `scripts/hook-stop.sh` is faster and more precise — this is the fallback.)

### Rate limits — `UsageMonitor.swift`

Claude Code's statusline mechanism delivers a JSON payload that includes `rate_limits.five_hour` and `rate_limits.seven_day` (used percentage + reset epoch). The bundled `scripts/statusline-bar.sh` persists each payload to `~/.claude/last-status.json`; `UsageMonitor` re-reads that file every minute and surfaces both windows as progress bars.

This data is only as fresh as the last statusline update — i.e. it goes stale when no session is running, the same limitation as Claude Code's `/usage` command.

### Cost & tokens — `UsageMonitor.swift`

Shells out to `ccusage blocks --json --offline` (active 5-hour billing block) and `ccusage daily --json --offline` (today's cost/tokens). The `ccusage` binary path is resolved once at init via `command -v` so the app doesn't depend on GUI-launch PATH. If ccusage is missing, the rest of the app still works.

## Concurrency notes

- Both monitors are `@MainActor @Observable`; timers hop back to the main actor.
- `ccusage` calls run on a detached utility-priority task since they can take a second or two; results are applied back on the main actor.
- `Shell.run` is a blocking helper with a deadline-based timeout (kills the process at the deadline) — fine for the short commands used here.

## Menu bar icon

`ClaudeSparkleIcon` hand-renders Claude's 4-petal sparkle into a 16pt template `NSImage` (four rotated quad-curve petals), so the system tints it correctly for light/dark menu bars and accent settings. No bundled image assets.

## Why a `.app` bundle from `build.sh`?

SwiftPM alone produces a bare executable. The build script wraps it with an `Info.plist` setting `LSUIElement=true` (no dock icon) and ad-hoc codesigns it — required for `UserNotifications` to work and for the app to behave as a proper menu-bar agent.
