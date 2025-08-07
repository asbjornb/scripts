$defaultBranch = git symbolic-ref refs/remotes/origin/HEAD 2>$null | Split-Path -Leaf
if (-not $defaultBranch) { $defaultBranch = "main" }

$base = git merge-base $defaultBranch HEAD
git diff $base HEAD | Set-Clipboard
Write-Output "Copied diff from $base to HEAD to clipboard."
