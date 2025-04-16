$base = git merge-base main HEAD
git diff $base HEAD | Set-Clipboard
Write-Output "Copied diff from $base to HEAD to clipboard."
