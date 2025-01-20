# Arch Linux Setup Automation

Automated post-installation setup script for Arch Linux. This script installs and configures a complete development environment with all necessary tools and applications.

## Quick Start

Run this command after a fresh Arch Linux installation:

```bash
curl -fsSL https://raw.githubusercontent.com/luizhcrocha/arch-setup/main/install.sh | bash
```

## What Gets Installed

### System Packages
- Network Management: NetworkManager, network-manager-applet
- Audio: pavucontrol
- Bluetooth: bluez, bluez-utils, blueman
- Terminal: ghostty
- Shell: zsh (with plugins)
- File Management: yazi, zoxide

### Development Tools
- GitHub CLI
- JetBrains Toolbox
- Chezmoi (dotfiles management)
- Atuin (shell history)
- 1Password
- Slack Desktop + CLI

### Additional Tools
- fzf (fuzzy finder)
- Fonts: JetBrains Mono Nerd Font
- swww (wallpaper)
- Notifications: libnotify, notification-daemon, swaync

## Post-Installation Configuration

The script automatically:
1. Sets up ZSH with popular plugins
2. Configures Git with user information
3. Initializes dotfiles using Chezmoi
4. Enables and starts system services (NetworkManager, Bluetooth)
5. Installs and configures the Slack CLI

## Manual Steps Required After Installation

1. Configure Atuin sync:
```bash
atuin login -u <USERNAME> -p <PASSWORD> -k <KEY>
atuin sync
```

## Repository Structure

```
arch-setup/
├── install.sh            # Main installation script
├── config/
│   ├── packages.yaml     # Package definitions & actions
│   └── settings.yaml     # Installation settings
└── scripts/
    └── utils/           # Utility scripts
        ├── logging.sh
        └── package.sh
```

## Development

### Prerequisites
- Fresh Arch Linux installation
- Internet connection
- Base development tools (automatically installed by the script)

### Manual Installation

If you prefer to run the installation step by step:

```bash
git clone https://github.com/luizhcrocha/arch-setup.git
cd arch-setup
chmod +x install.sh scripts/utils/*.sh
./install.sh
```

### Customization

To modify the packages or configurations:

1. Edit `config/packages.yaml` to add/remove packages
2. Edit `config/settings.yaml` to change installation behavior
3. Add post-installation actions in `config/packages.yaml` under `post_install_actions`

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## Troubleshooting

If you encounter any issues:

1. Check the logs at `/var/log/arch-setup.log`
2. Ensure all dependencies are installed
3. Verify your internet connection
4. Run the script without root privileges

## License

MIT License
