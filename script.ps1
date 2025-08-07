# Interactive script browser
param([string]$Filter = "")

$scriptsPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Get all scripts, filtered if specified
$scripts = Get-ChildItem -Path $scriptsPath -Filter "*.ps1" | 
    Where-Object { $Filter -eq "" -or $_.BaseName -like "*$Filter*" } |
    Sort-Object Name

if ($scripts.Count -eq 0) {
    Write-Host "No scripts found$(if ($Filter) { " matching: $Filter" })" -ForegroundColor Red
    return
}

$selectedIndex = 0

function Show-Menu {
    Clear-Host
    Write-Host "Scripts$(if ($Filter) { " (filtered: $Filter)" }):" -ForegroundColor Green
    Write-Host ""
    
    for ($i = 0; $i -lt $scripts.Count; $i++) {
        if ($i -eq $selectedIndex) {
            Write-Host "► $($scripts[$i].BaseName)" -ForegroundColor Yellow
        } else {
            Write-Host "  $($scripts[$i].BaseName)" -ForegroundColor Cyan
        }
    }
    
    Write-Host ""
    Write-Host "↑↓: Navigate | Enter: Run | V: View | Esc: Exit" -ForegroundColor Gray
}

while ($true) {
    Show-Menu
    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    switch ($key.VirtualKeyCode) {
        38 { # Up arrow
            $selectedIndex = if ($selectedIndex -gt 0) { $selectedIndex - 1 } else { $scripts.Count - 1 }
        }
        40 { # Down arrow  
            $selectedIndex = if ($selectedIndex -lt ($scripts.Count - 1)) { $selectedIndex + 1 } else { 0 }
        }
        13 { # Enter - Run script
            Clear-Host
            Write-Host "Running $($scripts[$selectedIndex].BaseName)..." -ForegroundColor Green
            & $scripts[$selectedIndex].FullName
            return
        }
        86 { # V - View content
            Clear-Host
            Write-Host "=== $($scripts[$selectedIndex].BaseName) ===" -ForegroundColor Green
            Get-Content $scripts[$selectedIndex].FullName
            Write-Host ""
            Write-Host "Press any key to return to menu..." -ForegroundColor Gray
            $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
        }
        27 { # Esc - Exit
            Clear-Host
            return
        }
    }
}