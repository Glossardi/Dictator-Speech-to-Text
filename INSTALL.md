# Installation Guide

Complete installation guide for Dictator voice-to-text menubar app.

## Prerequisites

### Required Software

1. **macOS** (Sonoma 14.0+)
2. **Hammerspoon** (0.9.97+)
3. **SoX** (Audio recording)
4. **OpenAI API Key** (with Whisper access)

### System Requirements

- macOS 14.0 or later
- Microphone access
- Internet connection
- ~10MB free disk space

## Quick Install

### 1. Install Dependencies

```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Hammerspoon
brew install hammerspoon --cask

# Install SoX
brew install sox

# Start Hammerspoon
open -a Hammerspoon
```

### 2. Install Dictator

#### Option A: Direct Install (Recommended)

```bash
# Clone repository
cd ~/Documents
git clone https://github.com/YOUR_USERNAME/Dictator.git
cd Dictator

# Copy files to Hammerspoon config directory
cp *.lua ~/.hammerspoon/

# Reload Hammerspoon
# Click Hammerspoon menubar icon → Reload Config
```

#### Option B: Symlink (For Development)

```bash
# Clone repository
cd ~/Documents
git clone https://github.com/YOUR_USERNAME/Dictator.git
cd Dictator

# Backup existing config (if any)
mv ~/.hammerspoon/init.lua ~/.hammerspoon/init.lua.backup 2>/dev/null || true

# Symlink files
for file in *.lua; do
    ln -sf "$(pwd)/$file" ~/.hammerspoon/
done

# Reload Hammerspoon
```

### 3. Grant Permissions

#### Accessibility Permission (Required for Fn key)

1. Open **System Settings**
2. Go to **Privacy & Security** → **Accessibility**
3. Enable **Hammerspoon**
4. Restart Hammerspoon if already running

#### Microphone Permission (Required for recording)

1. Open **System Settings**
2. Go to **Privacy & Security** → **Microphone**
3. Enable **Hammerspoon**

### 4. Configure API Key

1. Get your OpenAI API key: https://platform.openai.com/api-keys
2. Click the **Dictator menubar icon** (🎙️)
3. Navigate to **Settings** → **API Key**
4. Enter your API key (starts with `sk-`)
5. Click **OK**

### 5. Test Installation

1. Open any text editor (Notes, TextEdit, etc.)
2. Click in a text field
3. **Hold Fn key** and speak
4. **Release Fn key** when done
5. Text should appear automatically

## Verification

### Check Installation

```bash
# Verify Hammerspoon is running
pgrep -x Hammerspoon

# Verify SoX is installed
which rec

# Verify files are in place
ls ~/.hammerspoon/*.lua
```

Expected output:
```
/Users/YOUR_USERNAME/.hammerspoon/api.lua
/Users/YOUR_USERNAME/.hammerspoon/audio.lua
/Users/YOUR_USERNAME/.hammerspoon/config.lua
/Users/YOUR_USERNAME/.hammerspoon/init.lua
/Users/YOUR_USERNAME/.hammerspoon/rate_limiter.lua
/Users/YOUR_USERNAME/.hammerspoon/ui.lua
/Users/YOUR_USERNAME/.hammerspoon/utils.lua
```

### Open Hammerspoon Console

1. Click Hammerspoon menubar icon
2. Select **Console**
3. You should see: `Dictator initialized`

## Configuration

### Settings Menu

Access via Dictator menubar icon → Settings:

- **API Key**: Your OpenAI API key
- **Language**: Transcription language (`auto`, `en`, `de`, etc.)
- **Auto-Paste**: Toggle automatic text pasting
- **Use Fn Key (Hold)**: Toggle Fn key as recording hotkey
- **Set Custom Hotkey**: Configure alternative hotkey

### Rate Limiting

Default: 3 requests per 60 seconds

To change, edit `~/.hammerspoon/config.lua`:

```lua
M.defaultRateLimitMax = 5       -- Max requests
M.defaultRateLimitWindow = 60   -- Time window in seconds
```

Then reload: Hammerspoon menubar → Reload Config

## Troubleshooting

### Fn Key Not Working

1. Check Accessibility permission (Settings → Privacy & Security)
2. Open Hammerspoon Console
3. Look for: `Fn key watcher started successfully` ✓
4. If not, check error messages

### Recording Fails

1. Check Microphone permission
2. Test SoX: `rec test.wav trim 0 3` (records 3 seconds)
3. Check Console for errors

### API Errors

1. Verify API key is correct (starts with `sk-`)
2. Check OpenAI account has credits
3. Check internet connection
4. View Console for specific error messages

### Rate Limit

**Symptom:** "Rate limit reached. Please wait X seconds."

**Solution:** This is normal. Wait the specified time (usually 60s).

## Updating

### Pull Latest Changes

```bash
cd ~/Documents/Dictator
git pull origin main

# If using direct install:
cp *.lua ~/.hammerspoon/

# Reload Hammerspoon
# Menubar → Reload Config
```

## Uninstalling

```bash
# Remove Dictator files
rm ~/.hammerspoon/{api,audio,config,init,rate_limiter,ui,utils}.lua

# Remove settings
defaults delete org.hammerspoon.Hammerspoon com.simon.dictator.apiKey
defaults delete org.hammerspoon.Hammerspoon com.simon.dictator.language
# ... (other settings)

# Reload Hammerspoon
# Menubar → Reload Config

# Optionally uninstall dependencies
brew uninstall sox
brew uninstall hammerspoon --cask
```

## Support

For issues, questions, or feature requests:

1. Check [README.md](README.md) for features and usage
2. Check [CHANGELOG.md](CHANGELOG.md) for version history
3. Open an issue on GitHub
4. Include:
   - macOS version
   - Hammerspoon version
   - Console log output
   - Steps to reproduce

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - See [LICENSE](LICENSE) file for details.
