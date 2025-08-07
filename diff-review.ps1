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
    wsl_distro  = "ubuntu"
    claude_path = "/home/asbjornb/.nvm/versions/node/v22.16.0/bin/claude"
}

if (Test-Path $configPath) {
    try {
        $config = Get-Content $configPath | ConvertFrom-Json
        # Validate config values to prevent injection
        if ($config.wsl_distro -notmatch '^[a-zA-Z0-9._-]+$|^default$') {
            Write-Host "Warning: Invalid WSL distro in config, using default" -ForegroundColor Yellow
            $config.wsl_distro = $defaultConfig.wsl_distro
        }
        
        # Validate Claude path more robustly
        if (-not $config.claude_path -or -not (Test-Path $config.claude_path -IsValid)) {
            Write-Host "Warning: Invalid Claude path in config, using default" -ForegroundColor Yellow
            $config.claude_path = $defaultConfig.claude_path
        }
        else {
            # Additional security: ensure it's not a directory and looks like an executable
            $claudeFileName = Split-Path $config.claude_path -Leaf
            if ($claudeFileName -notmatch '^claude(\.(exe|sh|js))?$') {
                Write-Host "Warning: Claude path doesn't look like Claude executable, using default" -ForegroundColor Yellow
                $config.claude_path = $defaultConfig.claude_path
            }
        }
    }
    catch {
        Write-Host "Warning: Invalid config file, using defaults" -ForegroundColor Yellow
        $config = $defaultConfig
    }
}
else {
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

# Compact review options
Write-Host "Options: [Enter]=defaults, 1/2=uncommitted/branch, 3/4=quick/detailed, +text=context, h=help" -ForegroundColor Yellow

$userInput = Read-Host "Choice"

# Show help if requested
if ($userInput -eq "h" -or $userInput -eq "help") {
    Write-Host ""
    Write-Host "=== Diff Review Help ===" -ForegroundColor Green
    Write-Host ""
    Write-Host "Defaults (just press Enter):" -ForegroundColor Gray
    Write-Host "  • Uncommitted changes" -ForegroundColor Gray  
    Write-Host "  • Quick review mode" -ForegroundColor Gray
    Write-Host "  • No context" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Usage Examples:" -ForegroundColor Cyan
    Write-Host "  [Enter]                    Use all defaults" -ForegroundColor Green
    Write-Host "  2                          Branch changes, quick mode" -ForegroundColor Cyan
    Write-Host "  4                          Uncommitted, detailed mode" -ForegroundColor Cyan
    Write-Host "  24                         Branch changes, detailed mode" -ForegroundColor Cyan  
    Write-Host "  4This adds user auth       Uncommitted, detailed, with context" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Yellow
    Write-Host "  1 = Uncommitted changes (default)" -ForegroundColor Gray
    Write-Host "  2 = Branch changes vs main/master" -ForegroundColor Gray
    Write-Host "  3 = Quick review - just results (default)" -ForegroundColor Gray
    Write-Host "  4 = Detailed review - show Claude's thinking" -ForegroundColor Gray
    Write-Host "  Text after numbers = context description" -ForegroundColor Gray
    Write-Host ""
    
    $userInput = Read-Host "Choice"
}

# Parse the input using regex for robustness
$reviewBranch = $false # default (uncommitted changes)
$showThinking = $false # default
$context = ""

if ([string]::IsNullOrWhiteSpace($userInput)) {
    # Use all defaults
} else {
    # Use regex to parse: optional digit for changes, optional digit for mode, optional text
    if ($userInput -match '^([12])?([34])?(.*?)$') {
        $changesType = $matches[1]
        $reviewMode = $matches[2] 
        $contextText = $matches[3]
        
        # Validate and apply changes type
        if ($changesType -eq "2") {
            $reviewBranch = $true
        } elseif ($changesType -eq "1") {
            $reviewBranch = $false
        } elseif ($changesType -and $changesType -notin @("1", "2")) {
            Write-Host "Warning: Invalid changes type '$changesType', using default (uncommitted)" -ForegroundColor Yellow
        }
        
        # Validate and apply review mode
        if ($reviewMode -eq "4") {
            $showThinking = $true
        } elseif ($reviewMode -eq "3") {
            $showThinking = $false
        } elseif ($reviewMode -and $reviewMode -notin @("3", "4")) {
            Write-Host "Warning: Invalid review mode '$reviewMode', using default (quick)" -ForegroundColor Yellow
        }
        
        # Sanitize context to prevent injection
        $context = $contextText.Trim()
        if ($context.Length -gt 500) {
            Write-Host "Warning: Context truncated to 500 characters" -ForegroundColor Yellow
            $context = $context.Substring(0, 500)
        }
        # Remove potentially dangerous characters
        $context = $context -replace '[`$\\"]', ''
        
    } else {
        Write-Host "Warning: Invalid input format, using defaults" -ForegroundColor Yellow
    }
}

# Get the diff based on selection
if ($reviewBranch) {
    $defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | Split-Path -Leaf
    if (-not $defaultBranch) { $defaultBranch = "main" }
    $base = git merge-base $defaultBranch HEAD
    
    # Show only committed changes on this branch
    $diff = git diff $base HEAD
    $reviewType = "branch changes (vs $defaultBranch)"
} else {
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


# Build the review prompt
$contextSection = if ($context) {
    "`n`nContext: $context`n"
}
else { "" }

$reviewPrompt = @"
Please review this git diff as a merge request. It was made by my developer. You have access to the full repository context - feel free to examine related files, understand the broader codebase structure, and check how these changes fit into the overall architecture.$contextSection

Focus on:
1. Code quality and best practices
2. Potential bugs or issues  
3. Security considerations
4. Performance implications
5. Documentation needs
6. Test coverage gaps
7. Integration with existing code (check related files if needed)
8. Consistency with codebase patterns and conventions

Feel free to:
- Examine files that are imported/referenced in the diff
- Check for similar patterns elsewhere in the codebase
- Verify that interfaces and contracts are properly maintained
- Look at tests related to the changed functionality
- Review documentation that might need updates

Provide constructive feedback and suggestions for improvement.
"@

Write-Host ""
Write-Host "Reviewing $reviewType with Claude..." -ForegroundColor Green

# Use the Windows detection from earlier

if ($runningOnWindows) {
    # On Windows, pipe through WSL to run claude
    Write-Host "(Running Claude through WSL...)" -ForegroundColor Gray
    
    # Create a temp file for the diff to avoid command line length limits
    $tempFile = [System.IO.Path]::GetTempFileName()
    $diff | Out-File -FilePath $tempFile -Encoding UTF8
    
    try {
        # Use configured WSL distro and Claude path
        $wslTempPath = $tempFile.Replace('\', '/').Replace('C:', '/mnt/c')
        
        # Create a temp file for the prompt to avoid command injection
        $promptTempFile = [System.IO.Path]::GetTempFileName()
        $reviewPrompt | Out-File -FilePath $promptTempFile -Encoding UTF8
        $wslPromptPath = $promptTempFile.Replace('\', '/').Replace('C:', '/mnt/c')
        
        # Properly escape the Claude path for bash execution
        $escapedClaudePath = $CLAUDE_PATH -replace "'", "'\`"'\`"'"  # Escape single quotes
        
        # Create a secure command - add -p flag only if not showing thinking
        $claudeFlags = if ($showThinking) { "" } else { "-p" }
        $bashCommand = "cat '$wslTempPath' | '$escapedClaudePath' $claudeFlags `"`$(cat '$wslPromptPath')`""
        
        if ($WSL_DISTRO -eq "default") {
            wsl bash -c $bashCommand
        }
        else {
            wsl -d $WSL_DISTRO bash -c $bashCommand
        }
        
        Remove-Item $promptTempFile -ErrorAction SilentlyContinue
    }
    finally {
        Remove-Item $tempFile -ErrorAction SilentlyContinue
    }
}
else {
    # On Linux/WSL, run directly (ignore WSL config)
    if ($showThinking) {
        if ($CLAUDE_PATH -and (Test-Path $CLAUDE_PATH)) {
            $diff | & $CLAUDE_PATH $reviewPrompt
        }
        else {
            $diff | claude $reviewPrompt
        }
    } else {
        if ($CLAUDE_PATH -and (Test-Path $CLAUDE_PATH)) {
            $diff | & $CLAUDE_PATH -p $reviewPrompt
        }
        else {
            $diff | claude -p $reviewPrompt
        }
    }
}