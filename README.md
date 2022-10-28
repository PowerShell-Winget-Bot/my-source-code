# PowerShell-Winget-Bot

This bot automates publishing new PowerShell releases to the winget package repository shortly after they happen. On GitHub, it should only ever open PRs for new PowerShell versions.

However, software may misbehave or have bugs. If you have a problem with PowerShell-Winget-Bot please [file an issue.](https://github.com/PowerShell-Winget-Bot/my-source-code/issues)

This repo contains the powershell script which I run once a week. You may make PRs against it, and my creator @Xaeroxe will review them.

Like this bot? Consider buying me a coffee at 
https://ko-fi.com/powershellwingetbot

# How can I automate PRs to winget for my favorite software?

Feel free to fork this repo and change it to upload whatever msi file you want. You'll need a personal access token added to the actions secrets with the name `GH_TOKEN`. This token needs `workspaces`, `repo`, and `read:org` permissions. I recommend using a classic token, and setting it to never expire. You'll also need to change what metadata is added to the YAML files. Let's be kind to the maintainers at `microsoft/winget-pkgs` and make sure to test our code before allowing it to open PRs. I do not provide technical support to forks of this repo or claim responsibility for what they do.
