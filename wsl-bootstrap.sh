#!/bin/bash
set -e  # Exit on error

echo "📦 Updating and upgrading packages..."
sudo apt update && sudo apt upgrade -y

echo "🛠 Installing essential tools..."
sudo apt install -y curl git build-essential

echo "📂 Installing zoxide..."
sudo apt install -y zoxide
if ! grep -q 'zoxide init bash' ~/.bashrc; then
  echo 'eval "$(zoxide init bash)"' >> ~/.bashrc
fi

echo "⬇️ Installing Node.js LTS..."
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

echo "🧰 Setting up user-local npm global directory..."
mkdir -p ~/.npm-global
npm config set prefix '~/.npm-global'
if ! grep -q '.npm-global/bin' ~/.bashrc; then
  echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
fi
source ~/.bashrc

echo "🚀 Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code || echo "⚠️ Claude Code install failed, check permissions or API access."

echo "💙 Installing PowerShell..."
# Install PowerShell using Microsoft's package repository (already added above)
sudo apt install -y powershell

# Verify installation
echo "🧪 Checking PowerShell version..."
pwsh --version || echo "⚠️ PowerShell not installed correctly."

echo "📦 Installing .NET SDK 9.0 Preview..."

# Add Microsoft package feed
wget https://packages.microsoft.com/config/ubuntu/22.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
sudo dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

# Install dotnet SDK 9 preview
sudo apt update
sudo apt install -y dotnet-sdk-9.0

# Confirm installation
echo "🧪 Checking dotnet version..."
dotnet --version || echo "⚠️ dotnet not installed correctly."

echo "✅ Setup complete! Restart your terminal or run 'source ~/.bashrc' to apply changes."
