#!/bin/bash
# Update all system packages

echo -e "\033[32m=== Linux Package Update ===\033[0m"
echo -e "\033[33mUpdating package list...\033[0m"
sudo apt update

if [ $? -ne 0 ]; then
    echo -e "\033[31m❌ Failed to update package list\033[0m"
    exit 1
fi

echo ""
echo -e "\033[33mUpgrading packages...\033[0m"
sudo apt upgrade

echo ""
echo -e "\033[32m✅ Update complete!\033[0m"