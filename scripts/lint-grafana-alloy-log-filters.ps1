Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$sourcePath = Join-Path $repoRoot "infrastructure/monitoring/grafana/alloy/pod-logs-extra-processing.alloy"

if (-not (Test-Path $sourcePath)) {
  throw "Alloy log filter source was not found: $sourcePath"
}

$sourceLines = Get-Content $sourcePath
if ($sourceLines.Count -eq 0) {
  throw "Alloy log filter source is empty: $sourcePath"
}

$wrappedLines = New-Object System.Collections.Generic.List[string]
[void]$wrappedLines.Add('loki.write "validate_sink" {')
[void]$wrappedLines.Add('  endpoint {')
[void]$wrappedLines.Add('    url = "http://127.0.0.1:3100/loki/api/v1/push"')
[void]$wrappedLines.Add('  }')
[void]$wrappedLines.Add('}')
[void]$wrappedLines.Add('')
[void]$wrappedLines.Add('loki.process "pod_logs_extra_processing" {')
[void]$wrappedLines.Add('  forward_to = [loki.write.validate_sink.receiver]')
[void]$wrappedLines.Add('')
foreach ($line in $sourceLines) {
  if ($line.Length -eq 0) {
    [void]$wrappedLines.Add('')
  } else {
    [void]$wrappedLines.Add("  $line")
  }
}
[void]$wrappedLines.Add('}')

$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ("pod-logs-extra-processing.validate.{0}.alloy" -f [System.Guid]::NewGuid().ToString('N'))

try {
  Set-Content -Path $tempPath -Value $wrappedLines
  & alloy validate $tempPath
  if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
  }
} finally {
  if (Test-Path $tempPath) {
    Remove-Item $tempPath -Force
  }
}