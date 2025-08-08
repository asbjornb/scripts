#!/usr/bin/env pwsh
# Update all Chocolatey packages

Write-Host "=== Windows Package Update ===" -ForegroundColor Green

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host ""
    Write-Host "❌ Administrator privileges required" -ForegroundColor Red
    Write-Host "Please run this script as Administrator to update Chocolatey packages." -ForegroundColor Gray
    exit 1
}

# Check if Chocolatey is installed
$chocoInstalled = Get-Command choco -ErrorAction SilentlyContinue

if (-not $chocoInstalled) {
    Write-Host ""
    Write-Host "❌ Chocolatey not found" -ForegroundColor Red
    Write-Host "Install Chocolatey from https://chocolatey.org/install" -ForegroundColor Gray
    exit 1
}

Write-Host ""
Write-Host "Updating all Chocolatey packages..." -ForegroundColor Yellow
Write-Host ""

# Update all packages
choco upgrade all -y

Write-Host ""
Write-Host "✅ Update complete!" -ForegroundColor Green
