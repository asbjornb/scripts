# Simple script lister and viewer
param([string]$Name = "")

$scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($Name) {
    $script = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | Where-Object { $_.BaseName -like "*$Name*" } | Select-Object -First 1
    if ($script) {
        Get-Content $script.FullName
    } else {
        Write-Host "Script not found: $Name" -ForegroundColor Red
    }
} else {
    Write-Host "Available scripts:" -ForegroundColor Green
    Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | ForEach-Object {
        Write-Host "  $($_.BaseName)" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "Usage: script <name> to view content" -ForegroundColor Yellow
}