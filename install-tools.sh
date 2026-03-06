#!/usr/bin/env bash

set -e

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Installation directory
BASE_DIR="./install"
TOOLS_DIR="$BASE_DIR/tools"
BIN_DIR="$TOOLS_DIR/bin"

# Files to process
TOOLS_TO_PROCESS=(
    "delta-0.18.2-x86_64-unknown-linux-musl.tar.gz"
    "glow_2.1.1_Linux_x86_64.tar.gz"
    "kitty-0.45.0-x86_64.txz"
    "nvim-linux-x86_64.tar.gz"
    "zsh-plugins.tar.gz"
    "bin.tar.gz"
)

# Files to ignore
FILES_TO_IGNORE=(
    "Hack.zip"
    "avante.nvim.tar.xz"
)

# Check if file should be processed
should_process_file() {
    local file="$1"
    
    # Check if in ignore list
    for ignore_file in "${FILES_TO_IGNORE[@]}"; do
        if [[ "$file" == "$ignore_file" ]]; then
            return 1
        fi
    done
    
    # Check if in tools list
    for tool_file in "${TOOLS_TO_PROCESS[@]}"; do
        if [[ "$file" == "$tool_file" ]]; then
            return 0
        fi
    done
    
    return 1
}

# Merge bin.tar.gz parts if needed
merge_bin_parts() {
    if [[ -f "bin.tar.gz.part.0" ]]; then
        log_info "Found split bin.tar.gz files, merging..."
        
        if [[ -f "merge-bin.sh" ]]; then
            log_info "Running merge-bin.sh"
            ./merge-bin.sh
        else
            log_info "Merging bin.tar.gz.part.* files"
            cat bin.tar.gz.part.* > bin.tar.gz
        fi
        
        if [[ -f "bin.tar.gz" ]]; then
            log_success "Successfully merged bin.tar.gz"
        else
            log_error "Failed to merge bin.tar.gz"
            return 1
        fi
    fi
    return 0
}

# Detect archive format
detect_archive_type() {
    local file="$1"
    
    case "$file" in
        *.tar.gz|*.tgz)
            echo "tar.gz"
            ;;
        *.tar.xz)
            echo "tar.xz"
            ;;
        *.tar.bz2|*.tbz2)
            echo "tar.bz2"
            ;;
        *.zip)
            echo "zip"
            ;;
        *.txz)
            echo "txz"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Extract archive
extract_archive() {
    local archive="$1"
    local target_dir="$2"
    local archive_type=$(detect_archive_type "$archive")
    
    log_info "Extracting $archive to $target_dir"
    
    # Special handling for kitty - it has its own directory structure
    local strip_option="--strip-components=1"
    if [[ "$archive" == *"kitty"* ]]; then
        strip_option=""
        log_info "Special handling for kitty (preserving directory structure)"
    fi
    
    case "$archive_type" in
        tar.gz)
            tar -xzf "$archive" -C "$target_dir" $strip_option 2>/dev/null || {
                # Check if extraction actually worked (kitty might give warnings)
                if [[ "$archive" == *"kitty"* && -d "$target_dir" ]]; then
                    log_warning "Kitty extraction had warnings but directory was created"
                    return 0
                fi
                return 1
            }
            ;;
        tar.xz)
            tar -xJf "$archive" -C "$target_dir" $strip_option 2>/dev/null || {
                if [[ "$archive" == *"kitty"* && -d "$target_dir" ]]; then
                    log_warning "Kitty extraction had warnings but directory was created"
                    return 0
                fi
                return 1
            }
            ;;
        tar.bz2)
            tar -xjf "$archive" -C "$target_dir" $strip_option
            ;;
        zip)
            unzip -q "$archive" -d "$target_dir"
            ;;
        txz)
            tar -xJf "$archive" -C "$target_dir" $strip_option 2>/dev/null || {
                if [[ "$archive" == *"kitty"* && -d "$target_dir" ]]; then
                    log_warning "Kitty extraction had warnings but directory was created"
                    return 0
                fi
                return 1
            }
            ;;
        *)
            log_error "Unsupported archive format: $archive"
            return 1
            ;;
    esac
    
    return 0
}

# Find executable files
find_executables() {
    local dir="$1"
    local executables=()
    
    # Only these specific tools should be linked (excluding bin.tar.gz)
    local common_tools=("delta" "glow" "nvim" "kitty" "kitten")
    
    # Check root directory for common tools
    for tool in "${common_tools[@]}"; do
        if [[ -f "$dir/$tool" && -x "$dir/$tool" ]]; then
            executables+=("$dir/$tool")
        fi
    done
    
    # Check bin/ subdirectory for common tools only
    if [[ -d "$dir/bin" ]]; then
        for tool in "${common_tools[@]}"; do
            if [[ -f "$dir/bin/$tool" && -x "$dir/bin/$tool" ]]; then
                executables+=("$dir/bin/$tool")
            fi
        done
    fi
    
    echo "${executables[@]}"
}

# Create symlink for an executable
create_symlink() {
    local exe="$1"
    local exe_name=$(basename "$exe")
    local link_path="$BIN_DIR/$exe_name"
    
    # Get absolute path to executable
    local exe_abs
    if [[ "$exe" == /* ]]; then
        exe_abs="$exe"
    else
        exe_abs="$(cd "$(dirname "$exe")" && pwd)/$(basename "$exe")"
    fi
    
    # Check if symlink already exists and points to the same file
    if [[ -L "$link_path" ]]; then
        local target
        if command -v readlink >/dev/null 2>&1; then
            target=$(readlink -f "$link_path" 2>/dev/null || readlink "$link_path")
        else
            target=$(ls -l "$link_path" | awk '{print $NF}')
        fi
        
        local target_abs
        if [[ "$target" == /* ]]; then
            target_abs="$target"
        else
            target_abs="$(cd "$(dirname "$link_path")" && cd "$(dirname "$target")" && pwd)/$(basename "$target")" 2>/dev/null || echo "$target"
        fi
        
        if [[ "$target_abs" == "$exe_abs" ]]; then
            return 0
        fi
    fi
    
    # Remove existing file/symlink if different
    if [[ -e "$link_path" ]]; then
        rm -f "$link_path"
    fi
    
    # Create symlink with absolute path
    ln -sf "$exe_abs" "$link_path"
    
    # Test the executable
    if test_executable "$link_path"; then
        log_success "Created symlink: $exe_name (tested)"
    else
        log_warning "Created symlink: $exe_name (test failed)"
    fi
}

# Test if an executable works
test_executable() {
    local exe_path="$1"
    
    # Check if it exists
    if [[ ! -f "$exe_path" ]]; then
        return 1
    fi
    
    # Skip testing for library files and scripts
    local exe_name=$(basename "$exe_path")
    case "$exe_name" in
        *.so|*.dylib|*.dll|lib*|*plugin*|*.sh|*.zsh|*.py|*.pl)
            return 0
            ;;
    esac
    
    # Skip direct execution for tools that start interactive sessions
    case "$exe_name" in
        tmux|vim|vi|nano|less|more|top|htop|mysql|psql|ssh|ftp|sftp)
            # Just check if it has version/help option without running directly
            if "$exe_path" --version >/dev/null 2>&1 || \
               "$exe_path" -V >/dev/null 2>&1 || \
               "$exe_path" --help >/dev/null 2>&1; then
                return 0
            fi
            # If file exists and is executable, accept it
            [[ -x "$exe_path" ]] && return 0
            return 1
            ;;
    esac
    
    # Check if file appears to be a valid executable
    local file_type=""
    if command -v file >/dev/null 2>&1; then
        file_type=$(file -b "$exe_path" 2>/dev/null || echo "")
        # Check if it's an executable binary or script
        if [[ "$file_type" == *"ELF"* ]] || \
           [[ "$file_type" == *"executable"* ]] || \
           [[ "$file_type" == *"Mach-O"* ]] || \
           [[ "$file_type" == *"script"* ]] || \
           [[ "$file_type" == *"text"* ]]; then
            # File appears to be a valid executable/script
            # Try to run it with --version or similar (but don't fail if it doesn't work)
            if [[ -x "$exe_path" ]]; then
                # Try in a subshell to catch any errors
                (
                    # Try different version flags
                    if "$exe_path" --version >/dev/null 2>&1; then
                        exit 0
                    elif "$exe_path" -v >/dev/null 2>&1; then
                        exit 0
                    elif "$exe_path" --help >/dev/null 2>&1; then
                        exit 0
                    elif "$exe_path" version >/dev/null 2>&1; then
                        exit 0
                    elif "$exe_path" -h >/dev/null 2>&1; then
                        exit 0
                    else
                        # Some tools exit with non-zero when run without args
                        "$exe_path" >/dev/null 2>&1
                        exit 0
                    fi
                ) >/dev/null 2>&1 && return 0 || true
                
                # If execution failed but file looks valid, still return success
                # (might be wrong architecture like Linux binary on macOS)
                return 0
            else
                # Not executable but looks like a valid file
                return 0
            fi
        fi
    fi
    
    # Fallback: if it's a regular file and executable bit is set
    if [[ -f "$exe_path" ]] && [[ -x "$exe_path" || "$exe_path" =~ \.(sh|zsh|py|pl)$ ]]; then
        return 0
    fi
    
    return 1
}

# Process a tool archive
process_tool() {
    local archive="$1"
    
    log_info "Processing: $(basename "$archive")"
    
    # Clean tool name
    local tool_name=$(basename "$archive")
    tool_name="${tool_name%.tar.gz}"
    tool_name="${tool_name%.tgz}"
    tool_name="${tool_name%.tar.xz}"
    tool_name="${tool_name%.tar.bz2}"
    tool_name="${tool_name%.tbz2}"
    tool_name="${tool_name%.zip}"
    tool_name="${tool_name%.txz}"
    
    local tool_dir="$TOOLS_DIR/$tool_name"
    
    # Remove existing directory
    if [[ -d "$tool_dir" ]]; then
        rm -rf "$tool_dir"
    fi
    
    # Create directory and extract
    mkdir -p "$tool_dir"
    
    if extract_archive "$archive" "$tool_dir"; then
        log_success "Extraction successful: $tool_name"
        
        # Find and create symlinks for executables
        local executables=$(find_executables "$tool_dir")
        if [[ -n "$executables" ]]; then
            for exe in $executables; do
                create_symlink "$exe"
            done
        fi
        
        return 0
    else
        log_error "Extraction failed: $tool_name"
        return 1
    fi
}

# Create environment file
create_env_file() {
    local env_file="$TOOLS_DIR/tools.sh"
    
    log_info "Creating environment file: $env_file"
    
    local abs_install_dir
    abs_install_dir="$(cd "$BASE_DIR" && pwd)"
    
    cat > "$env_file" << EOF
#!/usr/bin/env bash

# Tools environment configuration
# Generated by install-tools.sh
# Add this line to your shell rc file: source "$abs_install_dir/tools/tools.sh"

# Add tools bin directory to PATH
if [[ -d "$abs_install_dir/tools/bin" ]]; then
    export PATH="$abs_install_dir/tools/bin:\$PATH"
    echo "Added $abs_install_dir/tools/bin to PATH"
fi

# Set ZSH plugins directory
if [[ -d "$abs_install_dir/tools/zsh-plugins" ]]; then
    export ZSH_PLUGINS="$abs_install_dir/tools/zsh-plugins"
fi
EOF
    
    chmod +x "$env_file"
    log_success "Environment file created: $env_file"
}

# Verify all symlinks are valid
check_symlinks() {
    log_info "Verifying symlinks..."
    
    local broken_links=0
    local working_links=0
    
    # Check each symlink in BIN_DIR
    for link in "$BIN_DIR"/*; do
        if [[ -L "$link" ]]; then
            local link_name=$(basename "$link")
            local target
            # Try to get the symlink target
            if command -v readlink >/dev/null 2>&1; then
                target=$(readlink -f "$link" 2>/dev/null || readlink "$link")
            else
                target=$(ls -l "$link" | awk '{print $NF}')
            fi
            
            # Try to find absolute path
            local target_abs="$target"
            if [[ "$target" != /* ]] && [[ -e "$(dirname "$link")/$target" ]]; then
                target_abs=$(cd "$(dirname "$link")" && cd "$(dirname "$target")" >/dev/null 2>&1 && pwd)/$(basename "$target" 2>/dev/null) || echo "$target"
            fi
            
            if [[ -n "$target" && -f "$target_abs" ]]; then
                # Test the executable
                if test_executable "$link"; then
                    ((++working_links))
                    # Show relative path from TOOLS_DIR if possible
                    local display_target="$target"
                    if [[ "$target_abs" == "$TOOLS_DIR"/* ]]; then
                        display_target="${target_abs#$TOOLS_DIR/}"
                    elif [[ "$target_abs" == "$BIN_DIR"/* ]]; then
                        display_target="${target_abs#$BIN_DIR/}"
                    fi
                    log_success "✓ $link_name -> $display_target"
                else
                    ((++broken_links))
                    log_error "✗ $link_name (target exists but not executable)"
                fi
            else
                ((++broken_links))
                log_error "✗ $link_name (broken symlink: $target)"
            fi
        elif [[ -f "$link" && -x "$link" ]]; then
            # Regular executable file (from bin.tar.gz)
            if test_executable "$link"; then
                ((++working_links))
                log_success "✓ $(basename "$link") (regular executable)"
            else
                ((++broken_links))
                log_error "✗ $(basename "$link") (executable file test failed)"
            fi
        fi
    done
    
    if [[ $broken_links -eq 0 ]]; then
        log_success "All $working_links symlinks/executables are valid"
    else
        log_warning "$broken_links broken links found (out of $((working_links + broken_links)))"
    fi
    
    echo ""
}

# Show executable versions
show_versions() {
    echo "========================================="
    echo "       Executable Versions"
    echo "========================================="
    echo ""
    
    for link in "$BIN_DIR"/*; do
        if [[ -L "$link" ]] || [[ -f "$link" && -x "$link" ]]; then
            local exe_name=$(basename "$link")
            local version=""
            
            # Try different version flags
            if "$link" --version >/dev/null 2>&1; then
                version=$("$link" --version 2>&1 | head -1)
            elif "$link" -V >/dev/null 2>&1; then
                version=$("$link" -V 2>&1 | head -1)
            elif "$link" version >/dev/null 2>&1; then
                version=$("$link" version 2>&1 | head -1)
            fi
            
            if [[ -n "$version" ]]; then
                echo "$exe_name: $version"
            else
                echo "$exe_name: (version not available)"
            fi
        fi
    done
    
    echo ""
}

# Show summary
show_summary() {
    echo "========================================="
    echo "       Installation Summary"
    echo "========================================="
    echo ""
    echo "Installation directory: $BASE_DIR"
    echo "Tools directory: $TOOLS_DIR"
    echo "Binary directory: $BIN_DIR"
    echo "Environment file: $TOOLS_DIR/tools.sh"
    echo ""
    echo "Tools to install:"
    
    for tool in "${TOOLS_TO_PROCESS[@]}"; do
        if [[ -f "$tool" ]]; then
            echo "  - $tool"
        fi
    done
    
    echo ""
    echo "Files to ignore:"
    for ignore_file in "${FILES_TO_IGNORE[@]}"; do
        if [[ -f "$ignore_file" ]]; then
            echo "  - $ignore_file"
        fi
    done
    echo ""
}

# Special handling for bin.tar.gz
process_bin_tar() {
    local archive="$1"
    
    log_info "Processing: $(basename "$archive")"
    
    # bin.tar.gz should be extracted directly to BIN_DIR
    # First, ensure BIN_DIR exists
    mkdir -p "$BIN_DIR"
    
    log_info "Extracting $archive to $BIN_DIR"
    
    # bin.tar.gz likely contains a top-level bin/ directory
    # Use --strip-components=1 to remove it and extract contents directly to BIN_DIR
    tar -xzf "$archive" -C "$BIN_DIR" --strip-components=1 --skip-old-files 2>/dev/null || {
        # Try without --skip-old-files if it fails (older tar versions)
        tar -xzf "$archive" -C "$BIN_DIR" --strip-components=1 2>/dev/null && {
            log_warning "Extracted without --skip-old-files (older tar version)"
            return 0
        }
        # If that fails, try without --strip-components (some versions might not have it)
        tar -xzf "$archive" -C "$BIN_DIR" 2>/dev/null && {
            log_warning "Extracted without --strip-components"
            # Move files from BIN_DIR/bin/ to BIN_DIR/ if needed
            if [[ -d "$BIN_DIR/bin" ]]; then
                log_info "Moving files from $BIN_DIR/bin/ to $BIN_DIR/"
                mv "$BIN_DIR/bin"/* "$BIN_DIR/" 2>/dev/null || true
                rmdir "$BIN_DIR/bin" 2>/dev/null || true
            fi
            return 0
        }
        log_error "Extraction failed: bin"
        return 1
    }
    
    log_success "Extraction successful: bin"
    return 0
}

# Main installation
main() {
    log_info "Ubuntu Tools Installation Script"
    
    # Show summary
    show_summary
    
    # Ask for confirmation
    echo -n "Continue with installation? [y/N]: "
    read confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    # Merge bin.tar.gz parts if needed
    merge_bin_parts
    
    # Create directories
    log_info "Creating directories..."
    mkdir -p "$TOOLS_DIR"
    mkdir -p "$BIN_DIR"
    
    # Process tools (excluding bin.tar.gz first)
    local success_count=0
    local total_count=0
    local processed_tools=()
    
    # First pass: process all tools except bin.tar.gz
    for tool in "${TOOLS_TO_PROCESS[@]}"; do
        if [[ -f "$tool" && "$tool" != "bin.tar.gz" ]]; then
            ((++total_count))
            processed_tools+=("$tool")
            if process_tool "$tool"; then
                ((++success_count))
            fi
        fi
    done
    
    # Second pass: process bin.tar.gz (if exists)
    if [[ -f "bin.tar.gz" ]]; then
        ((++total_count))
        if process_bin_tar "bin.tar.gz"; then
            ((++success_count))
        fi
    fi
    
    # Create environment file
    create_env_file
    
    # Verify symlinks
    check_symlinks
    
    # Show executable versions
    show_versions
    
    # Show completion message
    echo ""
    log_success "Installation completed!"
    log_info "Successfully processed $success_count of $total_count tools"
    log_info ""
    log_info "Tools installed in: $TOOLS_DIR"
    log_info "Executables bin: $BIN_DIR"
    log_info "Environment file: $TOOLS_DIR/tools.sh"
    log_info ""
    local abs_install_dir
    abs_install_dir="$(cd "$BASE_DIR" && pwd)"
    log_info "Next steps:"
    log_info "1. Add this line to your shell rc file:"
    log_info "   source \"$abs_install_dir/tools/tools.sh\""
    log_info "2. Reload your shell: source ~/.bashrc (or ~/.zshrc)"
}

# Run main function
main
