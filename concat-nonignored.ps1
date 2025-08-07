#!/usr/bin/env pwsh
param (
    [string]$OutputFile = "combined.txt"
)

# Get list of all non-gitignored files
$files = git ls-files

# Clear the output file if it exists
Remove-Item $OutputFile -ErrorAction Ignore

foreach ($file in $files) {
    if (Test-Path $file) {
        Add-Content -Path $OutputFile -Value "`n# ==== $file ====" # Optional header
        Get-Content $file | Add-Content -Path $OutputFile
    }
}

Write-Output "Combined $(($files | Measure-Object).Count) files into $OutputFile"
