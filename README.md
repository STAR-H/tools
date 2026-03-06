# Ubuntu Tools Installation Script

This repository contains automated scripts for installing and managing tools on Ubuntu servers.

## File Description

- `install-tools.sh` - Basic installation script with colored text menu
- `merge-bin.sh` - Script to merge split archive files

## Usage

### 1. Basic Installation Script

```bash
# Run installation script
./install-tools.sh
```

This script provides:
- Colored text interface
- Installation directory selection (~/.local, custom path)
- Automatic extraction of all supported archive formats
- Creation of symbolic links to unified bin directory
- Environment file generation (tools.sh)

## Supported Archive Formats

- `.tar.gz` / `.tgz`
- `.tar.xz`
- `.tar.bz2` / `.tbz2`
- `.zip`
- `.txz`

## Installation Directory Structure

```
<base_directory>/
└── tools/
    ├── bin/                    # Symbolic links to all executables
    ├── tools.sh                # Environment configuration file
    ├── tool1/                  # Installation directory for tool1
    ├── tool2/                  # Installation directory for tool2
    └── ...
```

## Key Features

1. **Automatic Extraction** - Automatically detects and extracts all supported archive formats
2. **Environment Management** - Creates tools.sh file with PATH configuration
3. **Symbolic Links** - Creates unified symbolic links for all executables
4. **Permission Management** - Properly handles file permissions
5. **Shell Compatibility** - Works with bash, zsh, fish and other shells
6. **Non-root Friendly** - Designed for users without root privileges

## Installation Steps

1. Run the installation script
2. Select base installation directory (~/.local or custom path)
3. Confirm installation configuration
4. Script automatically extracts all tools
5. Script creates tools.sh environment file
6. Manually add `source <path>/tools/tools.sh` to your shell rc file
7. Reload shell configuration or restart terminal

## Environment Setup

After installation, add this line to your shell rc file:

```bash
# For bash
echo 'source ~/.local/tools/tools.sh' >> ~/.bashrc

# For zsh
echo 'source ~/.local/tools/tools.sh' >> ~/.zshrc

# Then reload
source ~/.bashrc  # or source ~/.zshrc
```

## Notes

- Designed for non-root users (no /usr/local or /opt options)
- Ensure sufficient disk space
- Ensure extraction tools are available (tar, unzip, etc.)
- Custom path must have write permissions
