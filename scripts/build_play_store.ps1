# Builds a release Android App Bundle for Google Play with production API and Google Sign-In defines.
#
# Usage (from repo root):
#   .\scripts\build_play_store.ps1
#
# Override endpoints (e.g. staging):
#   .\scripts\build_play_store.ps1 -ApiBaseUrl "https://staging.example.com/api/v1/mobile" -PublicApiBaseUrl "https://staging.example.com"
#
# Output:
#   build\app\outputs\bundle\release\app-release.aab

param(
    [string]$ApiBaseUrl = "https://www.dukanest.com/api/v1/mobile",
    [string]$PublicApiBaseUrl = "https://www.dukanest.com",
    [string]$GoogleServerClientId = "772287815251-eb8r1f4bqpudek9pubvnrm36tnv9js05.apps.googleusercontent.com"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

Write-Host "Building Play Store AAB from: $repoRoot" -ForegroundColor Cyan
Write-Host "  API_BASE_URL          = $ApiBaseUrl"
Write-Host "  PUBLIC_API_BASE_URL   = $PublicApiBaseUrl"
Write-Host "  GOOGLE_SERVER_CLIENT_ID = $GoogleServerClientId"
Write-Host ""

& flutter build appbundle --release `
    "--dart-define=API_BASE_URL=$ApiBaseUrl" `
    "--dart-define=PUBLIC_API_BASE_URL=$PublicApiBaseUrl" `
    "--dart-define=GOOGLE_SERVER_CLIENT_ID=$GoogleServerClientId"

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$out = Join-Path $repoRoot "build\app\outputs\bundle\release\app-release.aab"
Write-Host ""
Write-Host "Done. AAB: $out" -ForegroundColor Green
