$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$manifest = Get-Content (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
foreach ($screen in $manifest.screens) {
  $dir = Join-Path (Join-Path $root 'screens') $screen.slug
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $png = Join-Path $dir 'screenshot.png'
  $htmlf = Join-Path $dir 'screen.html'
  Write-Host "Downloading $($screen.slug)..."
  & curl.exe -L -f -sS -o $png $screen.screenshotUrl
  if ($LASTEXITCODE -ne 0) { throw "screenshot failed: $($screen.slug)" }
  & curl.exe -L -f -sS -o $htmlf $screen.htmlUrl
  if ($LASTEXITCODE -ne 0) { throw "html failed: $($screen.slug)" }
}
Write-Host 'All downloads completed.'
