#!/usr/bin/env bash
# One-time setup after `claude plugin install kaizen@<marketplace>`. Idempotent.
#
# - links verify and branch-brief into ~/.local/bin;
# - clones the marketplace to ~/.local/share/kaizen/<marketplace>, the copy the weekly run edits
#   (not under ~/.claude, which Claude Code protects from edits even in acceptEdits mode);
# - writes and loads a LaunchAgent that runs scripts/weekly.sh on Thursdays at 08:30.
# Everything points at the marketplace clone under ~/.claude/plugins, which launchd can read
# (it can't read ~/Documents) and whose path survives plugin updates.
# Env: KAIZEN_REPORT_DIR (where reports go), KAIZEN_SOURCE (your working checkout,
# named in the merge command).
set -euo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKETPLACE="$(dirname "$PLUGIN")"
TARGET="$HOME/.local/share/kaizen/$(basename "$MARKETPLACE")"
LABEL="com.claude.kaizen.weekly"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/.claude/introspect-history/launchd.log"

mkdir -p "$HOME/.local/bin" "$HOME/.claude/introspect-history" "$(dirname "$TARGET")"
for helper in verify branch-brief; do
  chmod +x "$PLUGIN/scripts/$helper"
  ln -sfn "$PLUGIN/scripts/$helper" "$HOME/.local/bin/$helper"
done

if [[ ! -d "$TARGET/.git" ]]; then
  git clone -q "$(git -C "$MARKETPLACE" remote get-url origin)" "$TARGET"
fi

environment=""
for name in KAIZEN_REPORT_DIR KAIZEN_SOURCE; do
  [[ -n "${!name:-}" ]] && environment+="export $name='${!name}'; "
done

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string><string>-lc</string>
    <string>${environment}bash "$PLUGIN/scripts/weekly.sh"</string>
  </array>
  <key>StartCalendarInterval</key>
  <dict><key>Weekday</key><integer>4</integer><key>Hour</key><integer>8</integer><key>Minute</key><integer>30</integer></dict>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "kaizen: helpers linked, clone at $TARGET, $LABEL loaded (log: $LOG)"
