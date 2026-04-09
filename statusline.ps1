[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
# Read JSON from stdin
$json = $input | Out-String
$data = $json | ConvertFrom-Json
# Extract values with fallbacks for null/missing fields
$model = $data.model.display_name
$pct = if ($null -ne $data.context_window.used_percentage) { [int]$data.context_window.used_percentage } else { 0 }
# Rate limits (absent until first API response)
$fiveH = $null
$sevenD = $null
if ($data.rate_limits) {
    if ($null -ne $data.rate_limits.five_hour) { $fiveH = [int]$data.rate_limits.five_hour.used_percentage }
    if ($null -ne $data.rate_limits.seven_day) { $sevenD = [int]$data.rate_limits.seven_day.used_percentage }
}
# ANSI color codes
$cyan   = "$([char]27)[36m"
$white  = "$([char]27)[97m"
$green  = "$([char]27)[32m"
$yellow = "$([char]27)[33m"
$red    = "$([char]27)[31m"
$reset  = "$([char]27)[0m"
# Pick color based on usage percentage
function Get-UsageColor($val) {
    if ($val -ge 80) { return $red }
    if ($val -ge 60) { return $yellow }
    return $green
}
# Build 10-block context bar
$filled = [int]($pct / 10)
if ($filled -gt 10) { $filled = 10 }
$empty  = 10 - $filled
$fc  = [string][char]0x2593  # ▓
$ec  = [string][char]0x2591  # ░
$bar = $fc * $filled + $ec * $empty
$barColor = Get-UsageColor $pct
# Build rate limit section (only if data is available)
$ratePart = ''
if ($null -ne $fiveH -and $null -ne $sevenD) {
    $c5 = Get-UsageColor $fiveH
    $c7 = Get-UsageColor $sevenD
    $ratePart = " $reset| ${white}5h: ${c5}${fiveH}%${white} $([char]0x00B7) 7d: ${c7}${sevenD}%${reset}"
} elseif ($null -ne $fiveH) {
    $c5 = Get-UsageColor $fiveH
    $ratePart = " $reset| ${white}5h: ${c5}${fiveH}%${reset}"
} elseif ($null -ne $sevenD) {
    $c7 = Get-UsageColor $sevenD
    $ratePart = " $reset| ${white}7d: ${c7}${sevenD}%${reset}"
}
# Session duration via transcript file creation time (no files saved, dies with session)
$durationStr = ''
$transcriptPath = $data.transcript_path
if ($transcriptPath -and (Test-Path $transcriptPath)) {
    $dur = New-TimeSpan -Start (Get-Item $transcriptPath).CreationTime -End (Get-Date)
    if ($dur.Hours -gt 0) {
        $durationStr = " $reset| ${white}{0}h {1}m${reset}" -f $dur.Hours, $dur.Minutes
    } else {
        $durationStr = " $reset| ${white}{0}m {1}s${reset}" -f $dur.Minutes, $dur.Seconds
    }
}
# Output single line
[Console]::WriteLine("${cyan}[$model]${reset} ${barColor}${bar}${reset} ${white}${pct}%${reset}${ratePart}${durationStr}")
