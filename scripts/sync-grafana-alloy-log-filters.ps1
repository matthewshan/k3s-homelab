Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$valuesPath = Join-Path $repoRoot "infrastructure/monitoring/grafana/values.yaml"
$sourcePath = Join-Path $repoRoot "infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy"

$valuesLines = New-Object System.Collections.Generic.List[string]
Get-Content $valuesPath | ForEach-Object { [void]$valuesLines.Add($_) }

$sourceLines = Get-Content $sourcePath
if ($sourceLines.Count -eq 0) {
  throw "Alloy log filter source is empty: $sourcePath"
}

$generatedComment = "  # Generated from alloy/pod-logs-extra-processing.alloy by scripts/sync-grafana-alloy-log-filters.ps1."

$headerIndex = -1
for ($index = 0; $index -lt $valuesLines.Count; $index++) {
  if ($valuesLines[$index] -eq "  extraLogProcessingStages: |") {
    $headerIndex = $index
    break
  }
}

if ($headerIndex -lt 0) {
  throw "Could not find podLogs.extraLogProcessingStages in $valuesPath"
}

$replaceStartIndex = $headerIndex
if ($headerIndex -gt 0 -and $valuesLines[$headerIndex - 1] -eq $generatedComment) {
  $replaceStartIndex = $headerIndex - 1
}

$replaceEndIndex = $valuesLines.Count
for ($index = $headerIndex + 1; $index -lt $valuesLines.Count; $index++) {
  if ($valuesLines[$index] -match '^[A-Za-z][A-Za-z0-9_-]*:') {
    $replaceEndIndex = $index
    break
  }
}

$replacementLines = New-Object System.Collections.Generic.List[string]
[void]$replacementLines.Add($generatedComment)
[void]$replacementLines.Add("  extraLogProcessingStages: |")
foreach ($line in $sourceLines) {
  if ($line.Length -eq 0) {
    [void]$replacementLines.Add("    ")
  } else {
    [void]$replacementLines.Add("    $line")
  }
}

$updatedLines = New-Object System.Collections.Generic.List[string]
for ($index = 0; $index -lt $replaceStartIndex; $index++) {
  [void]$updatedLines.Add($valuesLines[$index])
}
foreach ($line in $replacementLines) {
  [void]$updatedLines.Add($line)
}
for ($index = $replaceEndIndex; $index -lt $valuesLines.Count; $index++) {
  [void]$updatedLines.Add($valuesLines[$index])
}

Set-Content -Path $valuesPath -Value $updatedLines
Write-Host "Updated $valuesPath from $sourcePath"