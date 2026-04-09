# Statusline Design

## Context

Claude Code supports a customizable statusline — a bar at the bottom of the terminal that runs a shell script and displays whatever it prints. The goal is to give the user an at-a-glance view of session health without having to ask Claude or check manually.

The user wants to know: which model is active, how much context is left, and how close they are to rate limits — all on one line, with colors that shift based on urgency.

## Design

### Display

Single line, three elements:

```
[Sonnet 4.6]  ▓▓▓▓░░░░░░ 38% | 5h: 23% · 7d: 12%
```

- **Model name** — always cyan, in brackets
- **Context bar** — 10-block progress bar + percentage, color-coded
- **Rate limits** — 5-hour and 7-day windows, each independently color-coded

### Color thresholds (applied to context bar and each rate limit independently)

| Usage | Color |
|-------|-------|
| Under 70% | Green |
| 70–90% | Yellow |
| Above 90% | Red |

### Script

- **Language:** PowerShell (built into Windows 11, no extra tools required)
- **Location:** `~/.claude/statusline.ps1`
- **Invoked via:** `settings.json` → `statusLine.command`

### Settings config

Add the following block to `~/.claude/settings.json`. Replace `<USERNAME>` with your Windows username:

```json
{
  "statusLine": {
    "type": "command",
    "command": "powershell -NoProfile -File C:/Users/<USERNAME>/.claude/statusline.ps1"
  }
}
```

### PowerShell script logic

1. Read stdin, parse as JSON with `ConvertFrom-Json`
2. Extract `model.display_name`, `context_window.used_percentage`, `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage`
3. Build 10-block bar from context percentage (▓ for filled, ░ for empty)
4. Apply color thresholds: green < 70, yellow 70–89, red ≥ 90
5. Each value (context %, 5h rate, 7d rate) gets its own color independently
6. Output single line with ANSI escape codes for color

### ANSI colors (PowerShell)

- Cyan: `$([char]27)[36m` — model name
- Green: `$([char]27)[32m`
- Yellow: `$([char]27)[33m`
- Red: `$([char]27)[31m`
- Reset: `$([char]27)[0m`

### Null/absent field handling

- `used_percentage` can be null early in session — fallback to `0`
- `rate_limits` is absent until first API response — display nothing for that section if absent
- All fallbacks handled with PowerShell's null-coalescing: `if ($val) { $val } else { 0 }`

## Verification

1. Copy `statusline.ps1` to `~\.claude\statusline.ps1`
2. Make sure `~\.claude\settings.json` has the `statusLine` block
3. Test the script manually:
   ```powershell
   '{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":38},"rate_limits":{"five_hour":{"used_percentage":23},"seven_day":{"used_percentage":12}}}' | powershell -NoProfile -File ~\.claude\statusline.ps1
   ```
4. Open Claude Code — statusline should appear at the bottom after the first message
5. Verify color changes by checking at different simulated usage levels
