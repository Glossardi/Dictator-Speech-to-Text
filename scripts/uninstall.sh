#!/usr/bin/env bash
# Dictator Uninstallation Script
# Removes Dictator from Hammerspoon with optional backup

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
readonly BACKUP_PATH="${BACKUP_DIR}/dictator_uninstall_backup_${TIMESTAMP}"

# List of Dictator files
readonly DICTATOR_FILES=(
    "init.lua"
    "config.lua"
    "config_defaults.lua"
    "audio.lua"
    "api.lua"
    "api_client.lua"
    "api_filters.lua"
    "ui.lua"
    "utils.lua"
    "rate_limiter.lua"
)

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

# Find existing Dictator files
find_dictator_files() {
    local found_files=()
    
    for file in "${DICTATOR_FILES[@]}"; do
        if [[ -f "${HAMMERSPOON_DIR}/${file}" ]]; then
            found_files+=("${file}")
        fi
    done
    
    echo "${found_files[@]}"
}

# Backup files before removal
backup_files() {
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return
    fi
    
    log_info "Creating backup of ${#files[@]} file(s)..."
    mkdir -p "${BACKUP_PATH}"
    
    for file in "${files[@]}"; do
        cp -p "${HAMMERSPOON_DIR}/${file}" "${BACKUP_PATH}/"
    done
    
    log_success "Backup created at: ${BACKUP_PATH}"
}

# Remove Dictator files
remove_files() {
    local files=("$@")
    
    if [[ ${#files[@]} -eq 0 ]]; then
        return
    fi
    
    log_info "Removing ${#files[@]} file(s)..."
    
    for file in "${files[@]}"; do
        rm -v "${HAMMERSPOON_DIR}/${file}"
    done
    
    log_success "Removed Dictator files"
}

# Clean up settings (optional)
clean_settings() {
    read -p "Remove saved settings (API key, preferences)? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing Dictator settings..."
        
        # Remove settings using Hammerspoon CLI or osascript
        if command -v hs &> /dev/null; then
            hs -c 'for _,k in ipairs(hs.settings.getKeys()) do if k:match("^com%.simon%.dictator") then hs.settings.clear(k) end end'
            log_success "Settings removed via hs CLI"
        else
            osascript -e 'tell application "Hammerspoon" to execute lua code "for _,k in ipairs(hs.settings.getKeys()) do if k:match(\"^com%%.simon%%.dictator\") then hs.settings.clear(k) end end"' 2>/dev/null && log_success "Settings removed via osascript" || log_warning "Could not remove settings automatically. You can remove them manually in Hammerspoon Console: for _,k in ipairs(hs.settings.getKeys()) do if k:match(\"^com%%.simon%%.dictator\") then hs.settings.clear(k) end end"
        fi
    else
        log_info "Settings preserved (will be available if you reinstall)"
    fi
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
        log_info "Hammerspoon is not running"
    fi
}

# Print uninstall summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Uninstallation complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Dictator has been removed from Hammerspoon."
    echo ""
    
    if [[ -d "${BACKUP_PATH}" ]]; then
        echo "A backup is available at:"
        echo "  ${BACKUP_PATH}"
        echo ""
        echo "To restore, run:"
        echo "  cp ${BACKUP_PATH}/*.lua ${HAMMERSPOON_DIR}/"
        echo ""
    fi
    
    echo "To reinstall Dictator in the future:"
    echo "  cd $(dirname "$0") && ./install.sh"
    echo ""
}

# Confirmation prompt
confirm_uninstall() {
    echo ""
    echo "This will remove Dictator from Hammerspoon."
    echo ""
    read -p "Continue with uninstallation? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Uninstallation cancelled"
        exit 0
    fi
}

# Main uninstallation flow
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Dictator - Uninstaller"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Find existing files
    local files=($(find_dictator_files))
    
    if [[ ${#files[@]} -eq 0 ]]; then
        echo ""
        log_warning "No Dictator files found in ${HAMMERSPOON_DIR}"
        echo ""
        echo "Dictator may not be installed, or files may have been manually removed."
        exit 0
    fi
    
    echo ""
    log_info "Found ${#files[@]} Dictator file(s):"
    for file in "${files[@]}"; do
        echo "  - ${file}"
    done
    
    confirm_uninstall
    backup_files "${files[@]}"
    remove_files "${files[@]}"
    clean_settings
    reload_hammerspoon
    print_summary
}

main "$@"
