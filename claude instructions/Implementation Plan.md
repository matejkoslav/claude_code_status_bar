# Statusline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a persistent single-line statusline to Claude Code showing model name, color-coded context bar, and rate limit usage.

**Architecture:** A PowerShell script reads JSON from stdin (piped by Claude Code) and prints one formatted line with ANSI colors. Claude Code is configured via `settings.json` to run this script after each response.

**Tech Stack:** PowerShell (built-in Windows 11), Claude Code `settings.json`

---

## File Map

| Action | Path                          | Purpose                       |
| ------ | ----------------------------- | ----------------------------- |
| Create | `~\.claude\statusline.ps1`    | The statusline script         |
| Modify | `~\.claude\settings.json`     | Add `statusLine` config block |

---

### Task 1: Create the PowerShell statusline script

**Files:**

- Create: `~\.claude\statusline.ps1`

- [ ] **Step 1: Write the script**

Copy `statusline.ps1` from this repo to `~\.claude\statusline.ps1`.

The current script content (see `statusline.ps1` in the repo root) reads JSON from stdin and outputs a single ANSI-colored line with model name, context bar, rate limits, session duration, and lines changed.

- [ ] **Step 2: Test the script with mock input (green state)**

Run this in PowerShell:

```powershell
'{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":38},"rate_limits":{"five_hour":{"used_percentage":23},"seven_day":{"used_percentage":12}}}' | powershell -NoProfile -File ~\.claude\statusline.ps1
```

Expected output (with colors): `[Sonnet 4.6] ▓▓▓░░░░░░░ 38% | 5h: 23% · 7d: 12%`

- Model in cyan
- Bar and percentage in green (38% < 70)
- Rate limits in green

- [ ] **Step 3: Test yellow threshold**

```powershell
'{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":76},"rate_limits":{"five_hour":{"used_percentage":74},"seven_day":{"used_percentage":38}}}' | powershell -NoProfile -File ~\.claude\statusline.ps1
```

Expected: bar + 76% in yellow, 5h: 74% in yellow, 7d: 38% in green

- [ ] **Step 4: Test red threshold**

```powershell
'{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":92},"rate_limits":{"five_hour":{"used_percentage":91},"seven_day":{"used_percentage":72}}}' | powershell -NoProfile -File ~\.claude\statusline.ps1
```

Expected: bar + 92% in red, 5h: 91% in red, 7d: 72% in yellow

- [ ] **Step 5: Test null handling (no rate limits yet)**

```powershell
'{"model":{"display_name":"Sonnet 4.6"},"context_window":{"used_percentage":null}}' | powershell -NoProfile -File ~\.claude\statusline.ps1
```

Expected: `[Sonnet 4.6] ░░░░░░░░░░ 0%` — no rate limit section, no crash

---

### Task 2: Wire up the script in settings.json

**Files:**

- Modify: `~\.claude\settings.json`

- [ ] **Step 1: Add the `statusLine` block**

Open `~\.claude\settings.json` and add the `statusLine` key. Replace `<USERNAME>` with your Windows username:

```json
"statusLine": {
  "type": "command",
  "command": "powershell -NoProfile -File C:/Users/<USERNAME>/.claude/statusline.ps1"
}
```

- [ ] **Step 2: Verify the JSON is valid**

Run:

```powershell
Get-Content ~\.claude\settings.json | ConvertFrom-Json
```

Expected: PowerShell prints the object with no errors. If it errors, the JSON has a syntax issue — check for missing commas or brackets.

---

### Task 3: Add lines added/removed display

**Files:**

- Modify: `~\.claude\statusline.ps1`

- [x] **Step 1: Read `cost.total_lines_added` / `cost.total_lines_removed` from JSON**

Added after the session duration block:

```powershell
# Lines added/removed
$linesPart = ''
if ($null -ne $data.cost -and ($null -ne $data.cost.total_lines_added -or $null -ne $data.cost.total_lines_removed)) {
    $added   = if ($null -ne $data.cost.total_lines_added)   { [int]$data.cost.total_lines_added }   else { 0 }
    $removed = if ($null -ne $data.cost.total_lines_removed) { [int]$data.cost.total_lines_removed } else { 0 }
    $linesPart = " $reset| ${green}+${added}${reset}/${red}-${removed}${reset}"
}
```

- [x] **Step 2: Append `$linesPart` to the output line**

`$linesPart` appended at the end of the `[Console]::WriteLine(...)` call.

Expected output segment: `| +42/-7` with `+42` in green and `-7` in red. Hidden when no lines have been changed yet.

---

### Task 4: End-to-end verification in Claude Code

- [ ] **Step 1: Send any message to Claude Code** (after editing a file)

After the response, look at the bottom of the terminal. The statusline should appear showing model, context bar, and rate limits (rate limits appear after the first API response).

- [ ] **Step 2: Confirm colors are visible**

Early in a session context usage will be low — bar should be green. If the terminal shows garbled characters instead of colors, the terminal doesn't support ANSI. In that case, strip the color escape codes from the script (remove all `$cyan`, `$green`, etc. variables and their usage).

- [ ] **Step 3: Confirm it works from a different project folder**

Open Claude Code in any other directory. The statusline should appear there too — confirming the global user settings are working.
