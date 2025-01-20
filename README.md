# Arch Linux Setup Automation

Automated post-installation setup script for Arch Linux. This script installs and configures a complete development environment with all necessary tools and applications.

## Quick Installation

Run this single command after a fresh Arch Linux installation:

```bash
curl -fsSL https://raw.githubusercontent.com/luizhcrocha/arch-setup/main/install.sh | bash
```

The script will:
1. Install required dependencies
2. Help you authenticate with GitHub
3. Clone the repository
4. Install and configure everything automatically

## What Gets Installed

### Development Tools
- Visual Studio Code
- GitHub CLI
- JetBrains Toolbox
- Docker + Docker Compose
- Chezmoi (dotfiles management)
- Git (configured)

### Terminal & Shell
- Ghostty Terminal
- ZSH with plugins:
  - autosuggestions
  - syntax-highlighting
  - fast-syntax-highlighting
  - autocomplete
- Yazi (file manager)
- Zoxide
- FZF
- Atuin (shell history)

### Applications
- 1Password
- Slack Desktop + CLI
- Network Manager
- Bluetooth tools
- PulseAudio control

### System & UI
- JetBrains Mono Nerd Font
- SWWW (wallpaper)
- Notification system (libnotify, swaync)

## Post-Installation Configuration

The script automatically:
1. Sets up ZSH with popular plugins
2. Configures Git with user information
3. Initializes dotfiles using Chezmoi
4. Enables and starts system services:
   - Docker
   - NetworkManager
   - Bluetooth
5. Adds user to docker group
6. Installs and configures the Slack CLI

## Manual Steps Required After Installation

1. Configure Atuin sync:
```bash
atuin login -u <USERNAME> -p <PASSWORD> -k <KEY>
atuin sync
```

2. Log out and log back in for Docker group membership to take effect

## Manual Installation (Alternative)

If you prefer to run the installation step by step:

```bash
# Clone the repository
git clone https://github.com/luizhcrocha/arch-setup.git
cd arch-setup
chmod +x install.sh scripts/utils/*.sh
./install.sh
```

## Troubleshooting

If you encounter any issues:

1. Check the logs at `/var/log/arch-setup.log`
2. Ensure all dependencies are installed
3. Verify your internet connection
4. Run the script without root privileges

## License

MIT License
