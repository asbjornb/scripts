param (
    [Parameter(Mandatory = $true)]
    [string]$PathToAdd
)

# Normalize and resolve path
$resolvedPath = (Resolve-Path $PathToAdd).Path

# Get current user PATH
$currentPath = [Environment]::GetEnvironmentVariable("PATH", "User")

# Check if it's already in PATH
if ($currentPath -like "*$resolvedPath*") {
    Write-Host "✔️  Already in PATH: $resolvedPath"
    return
}

# Add to PATH
$newPath = "$currentPath;$resolvedPath"
[Environment]::SetEnvironmentVariable("PATH", $newPath, "User")

Write-Host "✅ Added to PATH: $resolvedPath"
Write-Host "🔁 Restart your terminal for changes to take effect."