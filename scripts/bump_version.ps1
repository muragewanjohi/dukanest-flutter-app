param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("major", "minor", "patch")]
    [string]$Increment
)

$ErrorActionPreference = "Stop"

$pubspecPath = Join-Path $PSScriptRoot "..\pubspec.yaml"
$pubspecPath = [System.IO.Path]::GetFullPath($pubspecPath)

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml not found at: $pubspecPath"
}

$content = Get-Content -Path $pubspecPath -Raw
$match = [regex]::Match($content, "(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$")

if (-not $match.Success) {
    throw "Could not parse version from pubspec.yaml. Expected: version: x.y.z+n"
}

$major = [int]$match.Groups[1].Value
$minor = [int]$match.Groups[2].Value
$patch = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value

switch ($Increment) {
    "major" {
        $major += 1
        $minor = 0
        $patch = 0
    }
    "minor" {
        $minor += 1
        $patch = 0
    }
    "patch" {
        $patch += 1
    }
}

$build += 1
$newVersion = "$major.$minor.$patch+$build"
$newLine = "version: $newVersion"

$updated = [regex]::Replace(
    $content,
    "(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$",
    $newLine,
    1
)

Set-Content -Path $pubspecPath -Value $updated -NoNewline

Write-Output "Updated version to $newVersion"
