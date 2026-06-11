#!/bin/bash
# Claude Code Stop hook — fires a macOS notification when Claude finishes responding.
# Reads the hook JSON payload from stdin (see Claude Code hooks docs).

PAYLOAD="$(cat)"
CWD="$(printf '%s' "$PAYLOAD" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("cwd",""))' 2>/dev/null || true)"
SESSION_ID="$(printf '%s' "$PAYLOAD" | /usr/bin/python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("session_id",""))' 2>/dev/null || true)"

BASENAME="$(basename "${CWD:-Claude Code}")"
TITLE="Claude finished"
MSG="${BASENAME} · $(date +%H:%M)"

/usr/bin/osascript -e "display notification \"${MSG//\"/\\\"}\" with title \"${TITLE}\" sound name \"Glass\""

# Always allow Claude to stop normally (don't block)
exit 0
