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
        log_warning "SoX is not installed"
        
        if ! command -v brew &> /dev/null; then
            log_warning "Homebrew is not installed."
            echo "SoX is required for audio recording. We recommend installing it via Homebrew."
            read -p "Would you like to install Homebrew now? (This will take a few minutes) [y/N]: " install_brew
            if [[ "${install_brew}" =~ ^[Yy]$ ]]; then
                log_info "Installing Homebrew..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
                
                # Add brew to path for the rest of the script (M1/M2/M3 Mac)
                if [[ -f /opt/homebrew/bin/brew ]]; then
                    eval "$(/opt/homebrew/bin/brew shellenv)"
                fi
                
                if command -v brew &> /dev/null; then
                    log_success "Homebrew installed successfully."
                else
                    log_error "Homebrew installation failed or not found in path."
                    exit 1
                fi
            else
                log_error "SoX is required. Please install it manually or via Homebrew."
                exit 1
            fi
        fi
        
        log_info "Installing SoX via brew..."
        brew install sox
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
    echo "I will now open the Privacy & Security settings for you."
    echo "Please ensure Hammerspoon is enabled in both sections."
    echo ""
    
    # Open Accessibility settings
    log_info "Opening Accessibility settings..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    sleep 2
    
    # Open Microphone settings
    log_info "Opening Microphone settings..."
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    echo ""
    
    read -n 1 -s -r -p "Press any key once you have granted the permissions to continue..."
    echo ""
}

# Interactive configuration
configure_dictator() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Interactive Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Selection
    echo "Select your AI Provider:"
    echo "  1) OpenAI (Standard)"
    echo "  2) Groq (Fastest - Recommended)"
    echo "  3) DeepInfra (High quality & Fast)"
    echo "  4) Together AI (Good alternative)"
    echo "  5) Fireworks AI (Fast & reliable)"
    echo "  6) Cloudflare Workers AI"
    echo "  7) Custom / Other"
    echo "  s) Skip setup (configure later via menubar)"
    echo ""
    read -p "Selection [1-7/s]: " provider_choice
    
    if [[ "${provider_choice}" == "s" ]] || [[ -z "${provider_choice}" ]]; then
        log_info "Skipping interactive setup"
        return
    fi
    
    local api_key=""
    local base_url=""
    local model=""
    
    case ${provider_choice} in
        1)
            base_url="https://api.openai.com/v1"
            model="whisper-1"
            ;;
        2)
            base_url="https://api.groq.com/openai/v1"
            model="whisper-large-v3-turbo"
            ;;
        3)
            base_url="https://api.deepinfra.com/v1/openai"
            model="openai/whisper-large-v3-turbo"
            ;;
        4)
            base_url="https://api.together.xyz/v1"
            model="whisper-large-v3"
            ;;
        5)
            base_url="https://api.fireworks.ai/inference/v1"
            model="whisper-v3"
            ;;
        6)
            read -p "Enter your Cloudflare Account ID: " cf_account_id
            base_url="https://api.cloudflare.com/client/v4/accounts/${cf_account_id}"
            model="@cf/openai/whisper-large-v3-turbo"
            ;;
        7)
            read -p "Enter API Base URL: " base_url
            read -p "Enter Model Name: " model
            ;;
        *)
            log_warning "Invalid selection, skipping configuration"
            return
            ;;
    esac
    
    echo ""
    read -p "Enter your API Key: " api_key
    
    if [[ -z "${api_key}" ]]; then
        log_warning "API Key is empty. You will need to set it later."
    fi
    
    log_info "Applying settings..."
    
    # Use osascript to set settings in Hammerspoon
    # We set both transcription and correction settings for a better out-of-the-box experience
    local lua_code=""
    if [[ -n "${api_key}" ]]; then
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.apiKey', '${api_key}');"
    fi
    
    if [[ -n "${base_url}" ]]; then
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.transcriptionApiBaseUrl', '${base_url}');"
        # Most of these providers are also great for correction (except maybe specifically whisper-only ones)
        # But for now we just set transcription.
    fi
    
    if [[ -n "${model}" ]]; then
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.transcriptionModel', '${model}');"
    fi
    
    # For Groq, it also works great for correction
    if [[ "${provider_choice}" == "2" ]]; then
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.correctionApiBaseUrl', 'https://api.groq.com/openai/v1');"
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.correctionModel', 'llama-3.3-70b-versatile');"
        log_info "Configured Groq Llama-3.3-70b for text correction as well."
    elif [[ "${provider_choice}" == "1" ]]; then
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.correctionApiBaseUrl', 'https://api.openai.com/v1');"
        lua_code="${lua_code} hs.settings.set('com.simon.dictator.correctionModel', 'gpt-4o-mini');"
    fi
    
    if [[ -n "${lua_code}" ]]; then
        if pgrep -x "Hammerspoon" > /dev/null; then
            osascript -e "tell application \"Hammerspoon\" to execute lua code \"${lua_code}\"" > /dev/null 2>&1 || {
                log_warning "Could not auto-apply settings. Please configure manually via menubar."
                return
            }
            log_success "Settings applied successfully!"
        else
            log_warning "Hammerspoon is not running, settings could not be applied automatically."
            log_info "Settings will be applied once you start Hammerspoon and set them manually."
        fi
    fi
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
    configure_dictator
    check_permissions
    print_next_steps
}

main "$@"
