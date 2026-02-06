#!/usr/bin/env bash
# Dictator Update Script
# Updates Dictator to the latest version with automatic backup

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

# Get project root (parent directory of this script)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

# Check if Git repository
check_git_repo() {
    if [[ -d "${PROJECT_ROOT}/.git" ]]; then
        log_info "Git repository detected"
        return 0
    else
        log_warning "Not a Git repository - manual update only"
        return 1
    fi
}

# Check if SoX is installed
check_sox() {
    if ! command -v sox &> /dev/null; then
        log_warning "SoX is missing! This is required for recording."
        if command -v brew &> /dev/null; then
            log_info "Installing SoX via Homebrew..."
            brew install sox
        else
            log_error "Homebrew not found. Please install SoX manually."
        fi
    fi
}

# Update from Git
update_from_git() {
    log_info "Pulling latest changes from Git..."
    
    cd "${PROJECT_ROOT}"
    
    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "Uncommitted changes detected"
        read -p "Continue with update? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Update cancelled"
            exit 0
        fi
    fi
    
    # Pull latest changes
    # Try current branch first, fallback to common defaults
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    log_info "Current branch: ${branch}"
    
    if git pull origin "${branch}" 2>/dev/null; then
        log_success "Pulled changes from ${branch}"
    else
        log_warning "Could not pull from ${branch}, trying default..."
        git pull origin main || git pull origin master || {
            log_error "Failed to pull latest changes"
            echo "Please update manually with: git pull"
            exit 1
        }
    fi
    
    log_success "Updated local repository"
}

# Backup existing files
backup_existing_files() {
    local lua_files=()
    
    # Find existing Dictator-related files
    for file in "${PROJECT_ROOT}"/*.lua; do
        local basename=$(basename "${file}")
        if [[ -f "${HAMMERSPOON_DIR}/${basename}" ]]; then
            lua_files+=("${basename}")
        fi
    done
    
    if [[ ${#lua_files[@]} -eq 0 ]]; then
        log_warning "No existing Dictator files found in Hammerspoon directory"
        return
    fi
    
    log_info "Backing up ${#lua_files[@]} existing file(s)..."
    mkdir -p "${BACKUP_PATH}"
    
    for file in "${lua_files[@]}"; do
        cp -p "${HAMMERSPOON_DIR}/${file}" "${BACKUP_PATH}/"
    done
    
    log_success "Backup created at: ${BACKUP_PATH}"
}

# Install updated files
install_files() {
    log_info "Installing updated files..."
    
    local count=0
    for file in "${PROJECT_ROOT}"/*.lua; do
        if [[ -f "${file}" ]]; then
            cp -v "${file}" "${HAMMERSPOON_DIR}/"
            ((count++))
        fi
    done
    
    log_success "Updated ${count} Lua file(s)"
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

# Print update summary
print_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Update complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Your settings and API key have been preserved."
    echo "Backup available at: ${BACKUP_PATH}"
    echo ""
    echo "If you experience any issues:"
    echo "  1. Check the Hammerspoon Console for errors"
    echo "  2. Restore from backup if needed:"
    echo "     cp ${BACKUP_PATH}/*.lua ${HAMMERSPOON_DIR}/"
    echo ""
    read -n 1 -s -r -p "Press any key to finish..."
    echo ""
}

# Main update flow
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Dictator - Update Tool"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    if check_git_repo; then
        update_from_git
    fi
    
    check_sox
    backup_existing_files
    install_files
    reload_hammerspoon
    print_summary
}

main "$@"
