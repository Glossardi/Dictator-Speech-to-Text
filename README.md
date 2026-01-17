# Dictator – Voice-to-Text Menubar App for macOS

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Hammerspoon](https://img.shields.io/badge/Hammerspoon-0.9.97+-green.svg)](https://www.hammerspoon.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![GitHub stars](https://img.shields.io/github/stars/Glossardi/Dictator-Speech-to-Text?style=social) ![GitHub forks](https://img.shields.io/github/forks/Glossardi/Dictator-Speech-to-Text?style=social) ![GitHub issues](https://img.shields.io/github/issues/Glossardi/Dictator-Speech-to-Text)

A lightweight, **high-performance** macOS menubar application for voice dictation using OpenAI's Whisper API. Record audio with a hotkey, get instant transcription, and optionally auto-paste into any application.

Built with [Hammerspoon](https://www.hammerspoon.org/) for maximum reliability and performance.

---

## 📋 Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- **[Installation](#-installation)** ⭐
- **[Updating](#-updating-dictator)** 🔄
- **[Uninstalling](#️-uninstalling-dictator)** 🗑️
- [Quick Start](#-quick-start)
- [Configuration](#️-configuration)
- [Usage](#-usage)
- [Project Structure](#️-project-structure)
- [Troubleshooting](#-troubleshooting)
- [Development](#️-development)

---

## 🚀 Quick Start Guide

**New to Dictator? Start here!**

```bash
# 1. Install dependencies
brew install --cask hammerspoon
brew install sox

# 2. Clone and install
git clone https://github.com/Glossardi/Dictator-Speech-to-Text.git ~/Documents/Dictator
cd ~/Documents/Dictator
./install.sh

# 3. Grant permissions (System Settings → Privacy & Security)
#    - Accessibility → Enable Hammerspoon
#    - Microphone → Enable Hammerspoon

# 4. Get API key from DeepInfra (recommended) or OpenAI
#    - DeepInfra: https://deepinfra.com/ (faster & cheaper!)
#    - OpenAI: https://platform.openai.com/api-keys
#    - Cloudflare Workers AI: https://dash.cloudflare.com/ (AI → Workers AI)

# 5. Configure Dictator (menubar icon → Settings)
#    For DeepInfra (recommended):
#    - API Key: Your DeepInfra key
#    - Transcription API URL: https://api.deepinfra.com/v1/openai
#    - Transcription Model: openai/whisper-large-v3-turbo
#
#    For Cloudflare Workers AI:
#    - API Key: Your Cloudflare API Token
#    - Transcription API URL: https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}
#    - Transcription Model: @cf/openai/whisper-large-v3-turbo
#    - (Optional) Correction API URL: https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}
#    - (Optional) Correction Model: @cf/meta/llama-3.1-8b-instruct

# 6. Start dictating! Hold Fn key, speak, release ⚡
```

---

## ✨ Features

- **🎙️ Hold-to-Record**: Press and hold `Fn` key (or custom hotkey) to record audio
- **🤖 OpenAI Whisper**: Accurate transcription via OpenAI's Whisper API
- **🔌 Multi-Provider Support**: Switch between OpenAI, DeepInfra, Groq, Cloudflare Workers AI, or any OpenAI-compatible API
- **🚀 Groq Integration**: Blazing fast transcription - 200-300+ tokens/second with free tier!
- **⚡ DeepInfra Integration**: 2-5x faster and 50-70% cheaper than OpenAI!
- **☁️ Cloudflare Workers AI**: Global edge deployment with low latency and competitive pricing
- **📝 Manual Glossary**: Provide context words (technical terms, names) to improve transcription accuracy
- **✨ AI Correction (Optional)**: Post-process transcription with a fast LLM (default: `gpt-4o-mini`) for punctuation/grammar/paragraphs
- **📋 Auto-Paste**: Automatically paste transcribed text (toggle on/off)
- **⚙️ Configurable**: Set API key, custom hotkeys, language, API providers, and models
- **🎯 Minimal UI**: Clean menubar icon showing current status (🎙️ Idle, 🔴 Recording, ⏳ Processing, 🤖 AI)
- **🌍 Multi-language**: Support for multiple languages via Whisper API
- **🛡️ Rate Limiting**: Built-in rate limiter prevents exceeding API limits (3 requests/minute default)
- **🔄 Auto-Retry**: Exponential backoff with automatic retry on API errors (429, 5xx)
- **⚡ Debouncing**: Prevents accidental double-triggers from rapid hotkey presses
- **✅ Input Validation**: Validates API keys, audio file size (<25MB), URLs, and model names
- **🚀 Performance Optimized**:
  - FLAC compression reduces file sizes by ~50% (faster uploads)
  - Optimized curl flags for maximum transfer speed
  - Lossless quality for perfect transcription accuracy

---

## 🔧 Prerequisites

### Required Software

- **macOS** (tested on macOS Sonoma+)
- **Hammerspoon** – Automation framework for macOS
  ```bash
  brew install --cask hammerspoon
  ```
- **SoX** – Audio recording utility
  ```bash
  brew install sox
  ```

### API Key

You need an API key from one of these providers:

#### Option 1: OpenAI (Official)
- Create account: [platform.openai.com](https://platform.openai.com/)
- Get API key: [API Keys page](https://platform.openai.com/api-keys)
- Pricing: ~$0.006/minute (Whisper)

#### Option 2: Groq 🚀 (Fastest)
- Create account: [console.groq.com](https://console.groq.com/)
- Get API key from console
- **Blazing fast** - 200-300+ tokens/second
- **Free tier** - Perfect for testing
- Pricing: Competitive, free tier available
- Fastest Whisper implementation available

#### Option 3: DeepInfra ⚡ (Cost-Effective)
- Create account: [deepinfra.com](https://deepinfra.com/)
- Get API key from dashboard
- 2-5x faster, 50-70% cheaper than OpenAI
- Same Whisper models, 100% compatible
- Pricing: ~$0.0013-$0.0029/minute

#### Option 4: Cloudflare Workers AI
- Create account: [dash.cloudflare.com](https://dash.cloudflare.com/)
- Navigate to: **AI** → **Workers AI** → **Use REST API**
- Create API Token with "Workers AI Read" permissions
- Get your Account ID from dashboard
- Models: `@cf/openai/whisper-large-v3-turbo`, `@cf/openai/whisper`
- Correction models: `@cf/meta/llama-3.1-8b-instruct`, `@cf/qwen/qwen2.5-7b-instruct`
- Pricing: Competitive, includes free tier (10,000 neurons/day)
- Global edge deployment for low latency

### System Permissions

- **Accessibility Permission** for Hammerspoon (required for Fn key detection)
  - Go to: **System Settings** → **Privacy & Security** → **Accessibility**
  - Enable **Hammerspoon**

---

## 📦 Installation

Dictator offers multiple installation methods to suit different user preferences. Choose the one that works best for you!

### 🌟 Option 1: Automated Installer (Recommended for Beginners)

The easiest way to install Dictator with automatic dependency checks, backup, and Hammerspoon reload:

```bash
# Clone the repository
git clone https://github.com/Glossardi/Dictator-Speech-to-Text.git ~/Documents/Dictator

# Run the installer
cd ~/Documents/Dictator
./install.sh
```

**What the installer does:**

- ✅ Checks that Hammerspoon and SoX are installed
- ✅ Creates automatic backup of any existing files
- ✅ Installs all Dictator files to `~/.hammerspoon/`
- ✅ Reloads Hammerspoon configuration automatically
- ✅ Shows clear instructions for required permissions

---

### 🚀 Option 2: Quick Install (Using Makefile)

For users who already have dependencies installed:

```bash
# Clone the repository
git clone https://github.com/Glossardi/Dictator-Speech-to-Text.git ~/Documents/Dictator
cd ~/Documents/Dictator

# Install using make
make install
```

This uses the same automated installer script as Option 1.

---

### ⚙️ Option 3: Manual Installation (Advanced Users)

For users who want full control:

```bash
# 1. Install dependencies
brew install --cask hammerspoon
brew install sox

# 2. Clone repository
git clone https://github.com/Glossardi/Dictator-Speech-to-Text.git ~/Documents/Dictator
cd ~/Documents/Dictator

# 3. Copy files to Hammerspoon (with optional backup)
mkdir -p ~/.hammerspoon

# Optional: Backup existing files
mkdir -p ~/.hammerspoon_backup
cp -v ~/.hammerspoon/*.lua ~/.hammerspoon_backup/ 2>/dev/null || true

# Copy Dictator files
cp -v *.lua ~/.hammerspoon/

# 4. Reload Hammerspoon
# Click: Hammerspoon menubar icon → Reload Config
```

---

### 🔐 Required Permissions

After installation, grant these permissions for Dictator to work:

1. **Accessibility Permission** (for Fn key detection)

   - Go to: **System Settings** → **Privacy & Security** → **Accessibility**
   - Enable **Hammerspoon**

2. **Microphone Permission** (for audio recording)
   - Go to: **System Settings** → **Privacy & Security** → **Microphone**
   - Enable **Hammerspoon**

---

### ✅ Verify Installation

1. Look for the Dictator menubar icon (🎙️)
2. Click it and go to **Settings** → **Set API Key**
3. Add your OpenAI API key from [platform.openai.com](https://platform.openai.com/api-keys)
4. Test: Open any text editor, hold `Fn` key, speak, release
5. Text should appear automatically!

---

## 🔄 Updating Dictator

Keep Dictator up-to-date with the latest features and fixes:

### 🌟 Automated Update (Recommended)

```bash
cd ~/Documents/Dictator
./update.sh
```

**What the update script does:**

- ✅ Pulls latest changes from Git (if repository)
- ✅ Creates automatic backup of current installation
- ✅ Updates all files to latest version
- ✅ Preserves your settings and API key
- ✅ Reloads Hammerspoon automatically

**Your API key and all settings are preserved!**

---

### ⚙️ Using Makefile

```bash
cd ~/Documents/Dictator
make update
```

---

### 🔧 Manual Update

```bash
cd ~/Documents/Dictator

# Pull latest changes
git pull

# Copy updated files
cp -v *.lua ~/.hammerspoon/

# Reload Hammerspoon
# Click: Hammerspoon menubar icon → Reload Config
```

---

## 🗑️ Uninstalling Dictator

Remove Dictator cleanly from your system:

### 🌟 Automated Uninstaller (Recommended)

```bash
cd ~/Documents/Dictator
./uninstall.sh
```

**What the uninstaller does:**

- ✅ Creates final backup of all files
- ✅ Removes all Dictator files from Hammerspoon
- ✅ Optionally removes settings (API key, preferences)
- ✅ Reloads Hammerspoon configuration
- ✅ Shows how to restore if needed

---

### ⚙️ Using Makefile

```bash
cd ~/Documents/Dictator
make uninstall
```

---

### 🔧 Manual Uninstallation

```bash
# Remove Dictator files
cd ~/.hammerspoon
rm -f init.lua config.lua audio.lua api.lua ui.lua utils.lua rate_limiter.lua

# Optional: Remove settings
# Settings are stored in: ~/Library/Preferences/org.hammerspoon.Hammerspoon.plist
# They will be automatically reused if you reinstall

# Reload Hammerspoon
# Click: Hammerspoon menubar icon → Reload Config
```

---

## 🚀 Quick Start

1. **Configure API Key**: Dictator menubar icon → Settings → API Key (get from [OpenAI Platform](https://platform.openai.com/api-keys))
2. **Test**: Open any text editor, hold `Fn` key, speak, release
3. Text appears automatically!

---

## ⚙️ Configuration

Access all settings via the menubar icon:

### Settings Menu

- **API Key**: Set your OpenAI API key (or API key from alternative provider)
- **Language**: Set transcription language (`auto`, `en`, `de`, etc.)
- **Transcription API Settings**: Configure API provider for speech-to-text
  - **Set API Base URL**: Choose provider (OpenAI, DeepInfra, etc.)
  - **Set Model**: Select transcription model
- **Edit Glossary...**: Define context words to improve transcription accuracy
- **Auto-Paste**: Toggle automatic text pasting
- **Enable AI Correction**: Toggle post-processing of the transcription (default: OFF to avoid extra cost)
- **Correction Settings**: Configure API provider, model, and system prompt for AI correction
  - **Set API Base URL**: Choose provider for correction
  - **Set Model**: Select correction model
  - **Set System Prompt**: Customize correction behavior
- **Use Fn Key (Hold)**: Toggle Fn key as recording hotkey
- **Set Custom Hotkey**: Configure alternative hotkey (when Fn key is disabled)

### API Provider Configuration

Dictator supports **multiple AI providers** via OpenAI-compatible APIs. All providers work the same way - just change the API key, base URL, and model name.

#### Supported Providers

| Provider            | Base URL                                                          | Models                             | Best For                             |
| ------------------- | ----------------------------------------------------------------- | ---------------------------------- | ------------------------------------ |
| **Groq** 🚀         | `https://api.groq.com/openai/v1`                                  | `whisper-large-v3-turbo`           | **Fastest** (200-300+ tokens/s), Free tier |
| **DeepInfra** ⚡    | `https://api.deepinfra.com/v1/openai`                             | `openai/whisper-large-v3-turbo`    | **Cost-effective** (50-70% cheaper) |
| **OpenAI**          | `https://api.openai.com/v1`                                       | `whisper-1`                        | Standard, reliable                   |
| **Cloudflare** ☁️  | `https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}`      | `@cf/openai/whisper-large-v3-turbo` | Global edge, free tier (10k neurons/day) |

#### Quick Setup

1. **Get API Key**: Sign up at your chosen provider ([Groq](https://console.groq.com/) • [DeepInfra](https://deepinfra.com/) • [OpenAI](https://platform.openai.com/) • [Cloudflare](https://dash.cloudflare.com/))
2. **Configure Dictator**:
   - Settings → **API Key**: Paste your API key
   - Settings → **Transcription API Settings** → **Set API Base URL**: Enter base URL from table
   - Settings → **Transcription API Settings** → **Set Model**: Enter model from table
3. **Test**: Record a short audio to verify

**Important Notes:**
- 💡 **Groq**: Fastest option with generous free tier - perfect for testing
- 💰 **DeepInfra**: Best price/performance ratio - recommended for production
- 🌐 **Cloudflare**: Requires Account ID in URL (get from dashboard)
- ⚠️ Base URLs should **NOT** include `/audio/transcriptions` - it's added automatically

#### Provider-Specific Setup

**Cloudflare Workers AI** requires additional configuration:
- Get your Account ID from [Cloudflare Dashboard](https://dash.cloudflare.com/)
- Create API Token: AI → Workers AI → Use REST API → Create API Token
- Use format: `https://api.cloudflare.com/client/v4/accounts/{YOUR_ACCOUNT_ID}`
- Models use `@cf/` prefix (e.g., `@cf/openai/whisper-large-v3-turbo`)

---
- **Performance**: Global edge deployment provides low latency worldwide

#### Available Models

**Transcription Models:**

- `@cf/openai/whisper-large-v3-turbo` - Fastest, recommended
- `@cf/openai/whisper` - Standard quality

**Correction Models:**

- `@cf/meta/llama-3.1-8b-instruct` - Fast general-purpose
- `@cf/qwen/qwen2.5-7b-instruct` - Alternative option
- `@cf/deepseek-ai/deepseek-math-7b-instruct` - Math/technical focus
- `@cf/meta/llama-2-7b-chat-fp16` - Legacy option

See full model list: [developers.cloudflare.com/workers-ai/models](https://developers.cloudflare.com/workers-ai/models/)

#### Troubleshooting Cloudflare

1. **401 Unauthorized**: Check API token has "Workers AI Read" permission
2. **Account ID**: Verify correct Account ID in URL (visible in Cloudflare dashboard)
3. **Model not found**: Ensure model name uses `@cf/` prefix
4. **Timeout**: Cloudflare may take longer than other providers, this is normal
5. **Console logs**: Check Hammerspoon Console for "Provider: Cloudflare Workers AI"

#### Example Configuration

```lua
-- Transcription
Transcription API URL: https://api.cloudflare.com/client/v4/accounts/abc123def456
Transcription Model: @cf/openai/whisper-large-v3-turbo

-- Correction (optional)
Correction API URL: https://api.cloudflare.com/client/v4/accounts/abc123def456
Correction Model: @cf/meta/llama-3.1-8b-instruct
```

---

**Important Notes:**

- Each provider requires its own API key format
- URLs should NOT include the endpoint path (e.g., `/audio/transcriptions`)
- Model names must match the provider's format exactly (e.g., `openai/whisper-large-v3-turbo` for DeepInfra)
- DeepInfra requires the full model path including namespace (e.g., `openai/...`, `Qwen/...`)
- Test with a short recording to verify configuration

### AI Correction (Optional)

When enabled, Dictator will run an extra step after Whisper:

1. Whisper returns the raw transcription
2. A Chat Completions call corrects punctuation/grammar and adds paragraphs
3. The corrected text is pasted/copied

**Fail-open behavior:** If the correction call fails (network, API error, rate limit), Dictator will still paste/copy the original Whisper text so you never lose data.

### Manual Glossary (Whisper Prompt Parameter)

The **Edit Glossary...** feature allows you to provide context words to the Whisper API, improving recognition of technical terms, product names, acronyms, and other uncommon words.

#### How it Works

- Navigate to **Settings** → **Edit Glossary...**
- Enter your terms as a comma-separated list (or any format - it's passed as-is to Whisper)
- Examples:
  - `ZyntriQix, Digique Plus, CynapseFive, VortiQore V8`
  - `Hammerspoon, OpenAI, macOS, hs.settings`
  - `Dr. Smith, Project Apollo, Q.U.A.R.T.Z.`

#### Technical Details

- **Whisper API Limitation**: The `prompt` parameter is limited to **224 tokens** (~150-200 words). The API uses only the first 224 tokens and ignores the rest.
- **Best Practices**:
  - Keep your glossary concise and focused on terms actually used in your dictation
  - Comma-separated format works well, but any format is acceptable
  - Test with a few key terms first, then expand as needed
  - The glossary is stored persistently and used for all transcriptions
- **Logging**: When a glossary is active, the Hammerspoon Console will show a preview of the first 100 characters

#### When to Use the Glossary

- Technical documentation with specific product names
- Medical/legal terminology
- Names of people, companies, or projects
- Acronyms and abbreviations
- Domain-specific jargon

The glossary does **not** add content to your transcription - it only guides Whisper to recognize and spell words correctly that are actually spoken.


#### Option 1: Fn Key (Default)

- **Enable**: Check **Use Fn Key (Hold)** in settings
- **Usage**: Hold `Fn` to record, release to transcribe
- **Requires**: Accessibility permissions

#### Option 2: Custom Hotkey

- **Enable**: Uncheck **Use Fn Key (Hold)**
- **Configure**: Click **Set Custom Hotkey**
- **Format**: Enter modifiers and key (e.g., `cmd alt d`)
- **Valid modifiers**: `cmd`, `alt`, `ctrl`, `shift`

---

## 🎯 Usage

### With Auto-Paste Enabled (Default)

1. Click into any text field
2. Hold your configured hotkey (`Fn` or custom)
3. Speak your text
4. Release the hotkey
5. Text automatically appears in the active field

### With Auto-Paste Disabled

1. Hold your configured hotkey
2. Speak your text
3. Release the hotkey
4. Text is copied to clipboard (notification appears)
5. Press `Cmd+V` to paste manually

> **Note:** Text is always copied to clipboard. Very short taps (<0.4s) are ignored to prevent accidental triggers. Use **Copy Last Transcription** from the menubar to retrieve previous results.

---

## 🏗️ Project Structure

```
Dictator/
├── init.lua           # Main entry point, menu logic, hotkey binding
├── config.lua         # Configuration management (settings persistence)
├── audio.lua          # Audio recording via SoX
├── api.lua            # OpenAI API integration (Whisper transcription with retry logic)
├── ui.lua             # Menubar UI and status updates
├── utils.lua          # Utility functions (temp file handling, file validation)
├── rate_limiter.lua   # Token bucket rate limiter (prevents API abuse)
└── README.md          # This file
```

---

## 🐛 Troubleshooting

### Processing Hangs / App Stuck

**Symptom**: App remains in "Processing" state (⏳) indefinitely, nothing is pasted

**Cause**: This was a known issue caused by network errors, callback exceptions, and task management problems.

**✅ Fixed (Version 1.2.0+)**:

- **Robust Error Handling**: All API callbacks wrapped in pcall to prevent exceptions from hanging the app
- **Variable Scope Fix**: Fixed undefined `command` variable that caused callback crashes
- **Task Persistence**: All curl tasks are persisted to prevent garbage collection blocking
- **Direct curl invocation**: Removed shell wrapping (`/bin/sh -c`) to avoid subprocess forking issues
- **Global watchdog**: Automatically detects and resets stuck processing state after 90 seconds
- **Automatic Recovery**: App now gracefully handles all network and API errors without hanging
- **Improved logging**: Better visibility into errors with automatic API key redaction

**Built-in Recovery Mechanisms**:

1. **pcall Error Wrapping**: All callbacks protected against Lua errors
2. **Automatic State Reset**: Processing flag always cleared on errors
3. **Network Error Handling**: Graceful handling of DNS failures, timeouts, SSL errors
4. **Watchdog Timer**: Force-resets after 90 seconds if processing gets stuck
5. **Rate Limiting**: Prevents API abuse and shows clear wait times

**If you still experience issues**:

1. Check Hammerspoon Console for error messages (API key automatically redacted)
2. The app should auto-recover within 90 seconds maximum
3. If not, manually reload Hammerspoon: Click menubar icon → Reload Config
4. Report persistent issues with Console logs on GitHub

**Technical Details** (for developers):

- Previous versions had unhandled exceptions in hs.task callbacks that could leave the app in "processing" state
- Line 450 referenced undefined `command` variable causing "attempt to concatenate a nil value" error
- All critical callbacks now wrapped in pcall with proper error propagation
- Ensures callback is always invoked even on internal errors, preventing indefinite hangs

---

### Fn Key Not Working

**Symptom**: Nothing happens when holding Fn key

**Solutions**:

1. Check Hammerspoon Console for errors:
   - Open Hammerspoon → **Console**
   - Look for: `ERROR: Failed to start Fn key eventtap`
2. Enable Accessibility permission:
   - **System Settings** → **Privacy & Security** → **Accessibility**
   - Add/Enable **Hammerspoon**
3. Reload Hammerspoon config
4. Check Console for: `Fn key watcher started successfully` ✅

### Custom Hotkey Not Working

**Symptom**: Hotkey doesn't trigger recording

**Solutions**:

1. Ensure **Use Fn Key (Hold)** is **unchecked**
2. Check Console for: `Hotkey bound successfully`
3. Try a different key combination
4. Valid format: `cmd alt s`, `ctrl shift d`, etc.

### Auto-Paste Not Working

**Symptom**: Text copied to clipboard but not pasted

**Solutions**:

1. Ensure **Auto-Paste** is **checked** in menu
2. Check Console for: `Auto-pasting text...`
3. Make sure text editor has **focus** after recording
4. Wait 1-2 seconds before switching windows
5. Try disabling auto-paste and using manual `Cmd+V`

### Transcription Fails

**Symptom**: No text appears, error notification shown

**Solutions**:

1. Check Hammerspoon Console for detailed error messages
2. Verify API key is correct (must start with `sk-`)
3. Check OpenAI API quota/billing
4. **Rate Limit**: Wait if you see "Rate limit reached" message
5. **File Size**: Recording must be under 25MB (rarely an issue with FLAC at 16kHz mono)
6. Check internet connection
7. API retries automatically (up to 3 attempts with exponential backoff)

**Common Error Messages**:

- `"could not parse multi-part form"` - Fixed in latest version (proper shell escaping)
- `"Network error"` - Check internet connection, DNS resolution
- `"SSL/Certificate error"` - System time may be wrong, or SSL issues
- `"API Error: <message>"` - Check API status and API key validity
- `"Invalid API key format"` - Verify API key matches provider's format (OpenAI: `sk-...`, DeepInfra: different format)

### API Provider Issues

**Symptom**: Transcription fails with API errors after switching providers

**Solutions**:

1. **Verify API Key Format**: Each provider has different key formats
   - OpenAI: Starts with `sk-`
   - DeepInfra: Different format - check their documentation
2. **Check Base URL Format**:
   - Must start with `http://` or `https://`
   - Should NOT include endpoint path (no `/audio/transcriptions`)
   - Remove trailing slashes
   - Examples:
     - ✅ `https://api.openai.com/v1`
     - ✅ `https://api.deepinfra.com/v1/openai`
     - ❌ `https://api.openai.com/v1/audio/transcriptions`
     - ❌ `https://api.openai.com/v1/`
3. **Verify Model Name**: Model names are provider-specific
   - OpenAI: `whisper-1`, `gpt-4o-mini`
   - DeepInfra: `openai/whisper-large-v3-turbo` or `openai/whisper-large-v3` (note the namespace)
4. **Check Console Logs**: Open Hammerspoon Console to see exact API request details
   - Look for: `API Base URL: ...`, `Model: ...`
   - Check HTTP status codes in response logs
5. **Test with curl**: Manually test the API endpoint
   ```bash
   curl -X POST https://api.deepinfra.com/v1/openai/audio/transcriptions \
     -H "Authorization: Bearer YOUR_API_KEY" \
     -F "file=@test.flac" \
     -F "model=openai/whisper-large-v3-turbo"
   ```

### Rate Limit Errors

**Symptom**: "Rate limit reached. Please wait X seconds."

**Solutions**:

1. This is normal - OpenAI limits requests to ~3 per minute
2. Wait the specified time (shown in error message)
3. Rate limiter tracks this automatically
4. To adjust limits: Edit `config.lua` → `defaultRateLimitMax` and `defaultRateLimitWindow`
5. Check your OpenAI account tier for actual limits

### Recording Issues

**Symptom**: No audio captured or poor quality

**Solutions**:

1. Verify SoX is installed: `which rec` (should show path)
2. Test microphone: `rec test.flac rate 16k channels 1` (speak, then Ctrl+C)
3. Check microphone permissions:
   - **System Settings** → **Privacy & Security** → **Microphone**
   - Enable **Hammerspoon**
4. Recording format: FLAC at 16kHz mono is optimized for speech (lossless, 50% smaller than WAV)
5. Hold hotkey for at least 1-2 seconds to capture audio
6. Check Console for SoX errors: `SoX Error: <message>`

> **Tip:** If you only tap the hotkey very briefly (<0.4s), Dictator will intentionally ignore the recording to avoid accidental API calls. Hold the key slightly longer for a real dictation.

---

## 📊 Logging & Debugging

Access the **Hammerspoon Console** (menubar → Console) to view detailed logs:

> **Security note:** Avoid pasting Console logs publicly. Older versions logged the full OpenAI API key in the Whisper curl command; current versions redact it.

**What is logged** (with debounce info):

- Recording start/stop
- API requests/responses (including retry attempts and file sizes)
- Rate limiter status (tokens remaining)
- Transcription results
- Detailed error messages with context

**Log Levels**:

- `[info]` - Normal operations
- `[warning]` - Non-critical issues (rate limits, debounce blocks)
- `[error]` - Failures requiring attention
- `[debug]` - Detailed state information

**Useful Console Commands**:

```lua
-- Check Fn watcher status
print(fnWatcher and "Fn watcher exists" or "Fn watcher is nil")

-- Check auto-paste setting
print(config.getAutoPaste() and "Auto-Paste ON" or "Auto-Paste OFF")

-- Check use Fn key setting
print(config.getUseFnKey() and "Use Fn Key ON" or "Use Fn Key OFF")

-- View current processing state (from init.lua)
print("Processing: " .. tostring(M.isProcessing))
```

---

## 🛠️ Development

### Code Structure

- **Modular design**: Separation of concerns (UI, config, audio, API)
- **State management**: Persistent settings via `hs.settings`
- **Error handling**: Comprehensive logging for debugging
- **Event-driven**: Hotkey bindings and UI callbacks

### Testing

This project uses [Busted](https://lunarmodules.github.io/busted/) for automated testing with 92 unit tests covering all core modules (config, utils, rate_limiter, api).

```bash
# Setup (one-time)
make setup-dev

# Run all tests (~100ms)
make test

# Watch mode (auto-rerun on changes)
make test-watch

# Optional: Install pre-commit hook
cp scripts/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Test Coverage**: 92 tests covering configuration, validation, rate limiting, and API logic. All tests run without Hammerspoon using mocks, ensuring fast and reliable testing (~100ms execution time).
(all 92 tests should pass) 3. Reload Hammerspoon config (`⌘+R` in Hammerspoon menu) 4. Test manually and check Console for errors

**Note**: Tests run locally only. As a macOS-specific Hammerspoon project, CI/CD provides limited value since the app requires macOS and Hammerspoon runtime. Local testing with comprehensive mocks ensures code quality.

1. Make changes to `.lua` files
2. Run `make test` to verify changes
3. Reload Hammerspoon config (`⌘+R` in Hammerspoon menu)
4. Test manually and check Console for errors

### Contributing

Contributions welcome! Please:

- Follow existing code style and modular design
- Add tests for new features (92 existing tests in `spec/unit/`)
- Ensure `make test` passes before submitting
- Add comprehensive error handling and logging
- Update README for new features or changes

---

## ❓ FAQ (Frequently Asked Questions)

### How do I know if the installation was successful?

After running `./install.sh`, you should see:

- ✓ A green checkmark for each step
- The Dictator menubar icon (🎙️) in your menubar
- No errors in the Hammerspoon Console

### Will updating Dictator delete my API key and settings?

No! The update script automatically preserves all your settings including:

- API key
- Language preferences
- Glossary
- Hotkey configuration
- Auto-paste settings

A backup is created before updating, just in case.

### Can I use Dictator with other Hammerspoon scripts?

Yes! Dictator is designed to coexist with other Hammerspoon configurations. The installer:

- Creates backups before overwriting files
- Only installs Dictator-specific files
- Doesn't modify other Hammerspoon scripts

**Note:** If you have a custom `init.lua`, you may need to merge it manually or rename Dictator's modules.

### How do I switch between different versions?

```bash
cd ~/Documents/Dictator

# Check available versions
git tag

# Switch to specific version
git checkout v1.0.0
./install.sh

# Return to latest version
git checkout main
./update.sh
```

### What if the automated installer fails?

Use the [Manual Installation](#️-option-3-manual-installation-advanced-users) method instead. The automated installer performs additional checks, but manual installation is just as effective.

### How much does it cost to use Dictator?

Dictator itself is free and open-source (MIT license). You need an API key for transcription:

**DeepInfra (Recommended):**

- ~$0.0013-$0.0029 per minute of audio
- 1 hour of dictation ≈ $0.08-$0.17
- Free credits available for new accounts!
- **50-70% cheaper than OpenAI**

**OpenAI:**

- ~$0.006 per minute of audio
- 1 hour of dictation ≈ $0.36

AI correction (optional) adds minimal cost with efficient models like `Qwen/Qwen2.5-7B-Instruct` on DeepInfra.

### Can I use Dictator offline?

No, Dictator requires an internet connection to use OpenAI's Whisper API. The audio is processed in the cloud, not locally.

### Does Dictator store my voice recordings?

No! Dictator:

- Records audio to a temporary file
- Sends it to OpenAI API
- Immediately deletes the local recording after transcription
- Does not keep any audio files

OpenAI may retain data according to their [data policy](https://openai.com/policies/usage-policies).

### Which languages are supported?

Whisper supports 50+ languages including:

- English, German, Spanish, French, Italian
- Chinese, Japanese, Korean
- Arabic, Russian, Portuguese, Dutch
- And many more!

Set language in: **Settings → Set Language** (use `auto` for automatic detection)

---

## 💡 Tips & Best Practices

### 🎤 Recording Tips

- **Hold, don't tap**: Keep the hotkey pressed while speaking
- **Speak clearly**: Natural pace, not too fast or slow
- **Reduce noise**: Recording in a quiet environment improves accuracy
- **Microphone position**: Speak 15-30cm from your mic
- **Pause for punctuation**: Brief pauses help AI correction add proper punctuation

### ⚡ Performance Tips

- **Use AI correction sparingly**: It adds cost and latency (enable only when needed)
- **Keep glossary focused**: Add only terms you actually use
- **Monitor rate limits**: Default is 3 requests/minute (adjustable)
- **Check API quota**: Ensure you have sufficient OpenAI credits

### 🔒 Security Tips

- **Protect your API key**: Never share it publicly
- **Use environment variables**: For automation, consider storing keys securely
- **Monitor usage**: Check OpenAI dashboard for unexpected usage
- **Backup regularly**: Use the built-in backup feature

### 🛠️ Workflow Tips

- **Create keyboard shortcuts**: Use custom hotkeys for easier access
- **Combine with text expansion**: Use with tools like TextExpander
- **Use glossary effectively**: Add technical terms, names, acronyms
- **Test before important work**: Try a quick recording first
- **Keep Dictator updated**: Run `./update.sh` periodically

---

## 🤝 Contributing & Support

### Found a Bug?

1. Check the [Troubleshooting](#-troubleshooting) section
2. Look for errors in Hammerspoon Console
3. [Open an issue](https://github.com/Glossardi/Dictator-Speech-to-Text/issues) with:
   - OS version
   - Hammerspoon version
   - Steps to reproduce
   - Console logs (API key redacted)

### Want to Contribute?

Contributions are welcome! See [Development](#️-development) section for setup instructions.

---

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Hammerspoon](https://www.hammerspoon.org/) – macOS automation framework
- [OpenAI Whisper](https://openai.com/research/whisper) – Speech recognition AI
- [SoX](http://sox.sourceforge.net/) – Audio processing utility
