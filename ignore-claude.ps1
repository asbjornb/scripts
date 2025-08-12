#!/usr/bin/env pwsh

# Add .claude/settings.local.json to git's exclude file
$excludeFile = ".git/info/exclude"
$claudeSettings = ".claude/settings.local.json"

# Check if we're in a git repository
if (-not (Test-Path ".git")) {
    Write-Error "Not in a git repository"
    exit 1
}

# Ensure the .git/info directory exists
$infoDir = ".git/info"
if (-not (Test-Path $infoDir)) {
    New-Item -ItemType Directory -Path $infoDir -Force | Out-Null
}

# Check if the entry already exists
if (Test-Path $excludeFile) {
    $content = Get-Content $excludeFile
    if ($content -contains $claudeSettings) {
        Write-Host "Claude settings already ignored"
        exit 0
    }
}

# Add the entry
Add-Content -Path $excludeFile -Value $claudeSettings
Write-Host "Added $claudeSettings to git exclude"