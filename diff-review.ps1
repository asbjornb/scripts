#!/usr/bin/env pwsh
# Interactive diff review with Claude Code
#
# Configuration:
# The script creates a config file at ~/.claude-diff-config.json on first run.
# Edit this file to customize WSL distribution and Claude path.
# Example: {"wsl_distro": "ubuntu", "claude_path": "/home/username/.nvm/versions/node/v22.16.0/bin/claude"}

# Load or create configuration
$homeDir = if ($env:HOME) { $env:HOME } else { $env:USERPROFILE }
$configPath = Join-Path $homeDir ".claude-diff-config.json"
$defaultConfig = @{
    wsl_distro = "ubuntu"
    claude_path = "/home/asbjornb/.nvm/versions/node/v22.16.0/bin/claude"
}

if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
    } catch {
        Write-Host "⚠️  Invalid config file, using defaults" -ForegroundColor Yellow
        $config = $defaultConfig
    }
} else {
    # Create default config file
    $config = $defaultConfig
    $config | ConvertTo-Json | Out-File $configPath -Encoding UTF8
    Write-Host "📝 Created config file at $configPath" -ForegroundColor Cyan
    Write-Host "   Edit this file to customize WSL distro and Claude path" -ForegroundColor Gray
}

$WSL_DISTRO = $config.wsl_distro
$CLAUDE_PATH = $config.claude_path
Write-Host "=== Diff Review Setup ===" -ForegroundColor Green

# Validate we're in a git repository
$gitDir = git rev-parse --show-toplevel 2>$null
if (-not $gitDir) {
    Write-Host ""
    Write-Host "❌ Not in a git repository" -ForegroundColor Red
    Write-Host "Please navigate to a git repository and try again." -ForegroundColor Gray
    exit 1
}
Write-Host "Repository: $gitDir" -ForegroundColor Gray

# Check if claude is available (skip on Windows since we'll use WSL)
$runningOnWindows = $env:OS -eq "Windows_NT"
if (-not $runningOnWindows) {
    $claudeAvailable = Get-Command claude -ErrorAction SilentlyContinue
    if (-not $claudeAvailable) {
        Write-Host ""
        Write-Host "❌ Claude Code not found" -ForegroundColor Red
        Write-Host "Claude Code is required for diff review." -ForegroundColor Gray
        Write-Host "Install Claude Code: https://docs.anthropic.com/claude/docs" -ForegroundColor Gray
        exit 1
    }
}
Write-Host ""

# Choose what to review
Write-Host "What do you want to review?" -ForegroundColor Yellow
Write-Host "1. Branch changes (vs main/master)" -ForegroundColor Cyan
Write-Host "2. Uncommitted changes" -ForegroundColor Cyan
Write-Host ""
$choice = Read-Host "Choice (1 or 2)"

# Get the diff
if ($choice -eq "2") {
    # Show all uncommitted changes: staged + unstaged + untracked
    $stagedDiff = git diff --cached
    $unstagedDiff = git diff
    $untrackedFiles = git ls-files --others --exclude-standard
    
    $diff = ""
    if ($stagedDiff) { $diff += "=== STAGED CHANGES ===`n$stagedDiff`n`n" }
    if ($unstagedDiff) { $diff += "=== UNSTAGED CHANGES ===`n$unstagedDiff`n`n" }
    if ($untrackedFiles) {
        $diff += "=== UNTRACKED FILES ===`n"
        foreach ($file in $untrackedFiles) {
            $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
            if ($content) {
                $diff += "New file: $file`n$content`n`n"
            }
        }
    }
    $reviewType = "all uncommitted changes (staged + unstaged + untracked)"
}
else {
    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | Split-Path -Leaf
    if (-not $defaultBranch) { $defaultBranch = "main" }
    $base = git merge-base $defaultBranch HEAD
    
    # Show only committed changes on this branch
    $diff = git diff $base HEAD
    $reviewType = "branch changes (vs $defaultBranch)"
}

if (-not $diff) {
    Write-Host "No $reviewType to review" -ForegroundColor Yellow
    exit
}

# Check diff size and warn if large
$lineCount = ($diff -split "`n").Count
if ($lineCount -gt 300) {
    Write-Host ""
    Write-Host "⚠️  Large diff detected: $lineCount lines" -ForegroundColor Yellow
    $confirm = Read-Host "Continue with review of $lineCount lines? (y/N)"
    if ($confirm -notmatch '^y(es)?$') {
        Write-Host "Review cancelled" -ForegroundColor Gray
        exit
    }
    Write-Host ""
}

Write-Host ""
Write-Host "Add context about your changes (optional):" -ForegroundColor Yellow
Write-Host "What is the intended purpose of these changes?" -ForegroundColor Gray
$context = Read-Host

# Build the review prompt
$contextSection = if ($context) {
    "`n`nContext: $context`n"
}
else { "" }

$reviewPrompt = @"
Please review this git diff as a merge request.$contextSection

Focus on:
1. Code quality and best practices
2. Potential bugs or issues  
3. Security considerations
4. Performance implications
5. Documentation needs
6. Test coverage gaps

Provide constructive feedback and suggestions for improvement.
"@

Write-Host ""
Write-Host "Reviewing $reviewType with Claude..." -ForegroundColor Green

# Use the Windows detection from earlier

if ($runningOnWindows) {
    # On Windows, pipe through WSL to run claude
    Write-Host "(Running Claude through WSL...)" -ForegroundColor Gray
    
    # Escape the prompt for WSL command
    $escapedPrompt = $reviewPrompt -replace '"', '\"' -replace '`', '\`'
    
    # Create a temp file for the diff to avoid command line length limits
    $tempFile = [System.IO.Path]::GetTempFileName()
    $diff | Out-File -FilePath $tempFile -Encoding UTF8
    
    try {
        # Use configured WSL distro and Claude path
        $wslTempPath = $tempFile.Replace('\', '/').Replace('C:', '/mnt/c')
        
        if ($WSL_DISTRO -eq "default") {
            wsl bash -c "cat '$wslTempPath' | $CLAUDE_PATH -p `"$escapedPrompt`""
        } else {
            wsl -d $WSL_DISTRO bash -c "cat '$wslTempPath' | $CLAUDE_PATH -p `"$escapedPrompt`""
        }
    } finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
} else {
    # On Linux/WSL, run directly (ignore WSL config)
    if ($CLAUDE_PATH -and (Test-Path $CLAUDE_PATH)) {
        $diff | & $CLAUDE_PATH -p $reviewPrompt
    } else {
        $diff | claude -p $reviewPrompt
    }
}