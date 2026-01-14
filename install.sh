#!/usr/bin/env bash
# Dictator Installation Script
# Installs Dictator to Hammerspoon directory with automatic backup

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Configuration
readonly HAMMERSPOON_DIR="${HOME}/.hammerspoon"
readonly BACKUP_DIR="${HAMMERSPOON_DIR}/backups"
readonly TIMESTAMP=$(date +%Y%m%d_%H%M%S)
readonly BACKUP_PATH="${BACKUP_DIR}/dictator_backup_${TIMESTAMP}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if Hammerspoon is installed
check_hammerspoon() {
    if [[ ! -d "/Applications/Hammerspoon.app" ]]; then
        log_error "Hammerspoon is not installed"
        echo ""
        echo "Please install Hammerspoon first:"
        echo "  brew install --cask hammerspoon"
        echo ""
        echo "Or download from: https://www.hammerspoon.org/"
        exit 1
    fi
    log_success "Hammerspoon is installed"
}

# Check if SoX is installed
check_sox() {
    if ! command -v sox &> /dev/null; then
        log_error "SoX is not installed"
        echo ""
        echo "Please install SoX:"
        echo "  brew install sox"
        exit 1
    fi
    log_success "SoX is installed"
}

# Create Hammerspoon directory if it doesn't exist
create_hammerspoon_dir() {
    if [[ ! -d "${HAMMERSPOON_DIR}" ]]; then
        log_info "Creating Hammerspoon directory..."
        mkdir -p "${HAMMERSPOON_DIR}"
        log_success "Created ${HAMMERSPOON_DIR}"
    fi
}

# Backup existing Dictator files
backup_existing_files() {
    local lua_files=()
    
    # Find existing Dictator-related files
    for file in "${SCRIPT_DIR}"/*.lua; do
        local basename=$(basename "${file}")
        if [[ -f "${HAMMERSPOON_DIR}/${basename}" ]]; then
            lua_files+=("${basename}")
        fi
    done
    
    if [[ ${#lua_files[@]} -eq 0 ]]; then
        log_info "No existing Dictator files found, skipping backup"
        return
    fi
    
    log_info "Backing up ${#lua_files[@]} existing file(s)..."
    mkdir -p "${BACKUP_PATH}"
    
    for file in "${lua_files[@]}"; do
        cp -p "${HAMMERSPOON_DIR}/${file}" "${BACKUP_PATH}/"
    done
    
    log_success "Backup created at: ${BACKUP_PATH}"
}

# Install Lua files
install_files() {
    log_info "Installing Dictator files..."
    
    local count=0
    for file in "${SCRIPT_DIR}"/*.lua; do
        if [[ -f "${file}" ]]; then
            cp -v "${file}" "${HAMMERSPOON_DIR}/"
            ((count++))
        fi
    done
    
    log_success "Installed ${count} Lua file(s)"
}

# Reload Hammerspoon config
reload_hammerspoon() {
    log_info "Reloading Hammerspoon configuration..."
    
    if pgrep -x "Hammerspoon" > /dev/null; then
        osascript -e 'tell application "Hammerspoon" to reload' 2>/dev/null || {
            log_warning "Could not auto-reload Hammerspoon"
            echo "  Please reload manually: Hammerspoon menubar → Reload Config"
            return
        }
        log_success "Hammerspoon reloaded"
    else
        log_warning "Hammerspoon is not running"
        echo "  Please start Hammerspoon and reload the config"
    fi
}

# Check required permissions
check_permissions() {
    log_info "Checking system permissions..."
    echo ""
    echo "Dictator requires the following permissions:"
    echo "  1. Accessibility (for Fn key detection)"
    echo "  2. Microphone (for audio recording)"
    echo ""
    echo "To grant permissions:"
    echo "  System Settings → Privacy & Security → Accessibility → Enable Hammerspoon"
    echo "  System Settings → Privacy & Security → Microphone → Enable Hammerspoon"
    echo ""
}

# Print next steps
print_next_steps() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Installation complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next steps:"
    echo "  1. Grant system permissions (see above)"
    echo "  2. Click the Dictator menubar icon"
    echo "  3. Go to Settings → Set API Key"
    echo "  4. Add your OpenAI API key (get it from platform.openai.com)"
    echo "  5. Hold Fn key, speak, and release!"
    echo ""
    echo "For more information, see: ${SCRIPT_DIR}/README.md"
    echo ""
}

# Main installation flow
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Dictator - Voice-to-Text Installer"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    check_hammerspoon
    check_sox
    create_hammerspoon_dir
    backup_existing_files
    install_files
    reload_hammerspoon
    check_permissions
    print_next_steps
}

main "$@"
