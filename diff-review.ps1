# Interactive diff review with Claude Code
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

# Check if claude is available
$claudeAvailable = Get-Command claude -ErrorAction SilentlyContinue
if (-not $claudeAvailable) {
    Write-Host ""
    Write-Host "❌ Claude Code not found" -ForegroundColor Red
    Write-Host "Claude Code is required for diff review." -ForegroundColor Gray
    Write-Host "If you're on Windows, try running this from WSL." -ForegroundColor Gray
    Write-Host "Otherwise, install Claude Code: https://docs.anthropic.com/claude/docs" -ForegroundColor Gray
    exit 1
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
$diff | claude -p $reviewPrompt