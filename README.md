# Dictator – Voice-to-Text Menubar App for macOS

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Hammerspoon](https://img.shields.io/badge/Hammerspoon-0.9.97+-green.svg)](https://www.hammerspoon.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![GitHub stars](https://img.shields.io/github/stars/Glossardi/Dictator-Speech-to-Text?style=social) ![GitHub forks](https://img.shields.io/github/forks/Glossardi/Dictator-Speech-to-Text?style=social) ![GitHub issues](https://img.shields.io/github/issues/Glossardi/Dictator-Speech-to-Text)

A lightweight, **high-performance** macOS menubar application for voice dictation using OpenAI's Whisper API. Record audio with a hotkey, get instant transcription, and optionally auto-paste into any application.

Built with [Hammerspoon](https://www.hammerspoon.org/) for maximum reliability and performance.

---

## ✨ Features

- **🎙️ Hold-to-Record**: Press and hold `Fn` key (or custom hotkey) to record audio
- **🤖 OpenAI Whisper**: Accurate transcription via OpenAI's Whisper API
- **📋 Auto-Paste**: Automatically paste transcribed text (toggle on/off)
- **⚙️ Configurable**: Set API key, custom hotkeys, language, and auto-paste behavior
- **🎯 Minimal UI**: Clean menubar icon showing current status (🎙️ Idle, 🔴 Recording, ⏳ Processing)
- **🌍 Multi-language**: Support for multiple languages via Whisper API
- **🛡️ Rate Limiting**: Built-in rate limiter prevents exceeding API limits (3 requests/minute default)
- **🔄 Auto-Retry**: Exponential backoff with automatic retry on API errors (429, 5xx)
- **⚡ Debouncing**: Prevents accidental double-triggers from rapid hotkey presses
- **✅ Input Validation**: Validates API keys, audio file size (<25MB), and configuration
- **🚀 Performance Optimized**:
  - FLAC compression reduces file sizes by ~50% (faster uploads)
  - Optimized curl flags for maximum transfer speed
  - Lossless quality for perfect transcription accuracy

---

## ⚡ Performance Optimizations

### Audio Format

- **FLAC compression** with 16kHz mono (lossless)
- **~50% file size reduction** vs WAV (e.g., 2 sec: 125KB → 59KB)
- **Lossless quality**: Perfect for speech transcription, no quality loss
- **Native SoX support**: Reliable recording without extra dependencies

### Network Transfer

- **HTTP compression** enabled (`--compressed`)
- **TCP optimizations**: No-delay flag for faster packet delivery
- **Proper multipart encoding**: Prevents parsing errors
- **Smart error detection**: Specific handling for SSL, network, and parsing issues

### Processing

- **Shell escaping**: Secure, reliable handling of special characters
- **Detailed logging**: File sizes, commands, and timing for debugging
- **Retry intelligence**: Differentiates between retryable and permanent errors

---

## 🔧 Prerequisites

### Required Software

- **macOS** (tested on macOS Sonoma+)
- **Hammerspoon** – Automation framework for macOS
  ```bash
  brew install hammerspoon
  ```
- **SoX** – Audio recording utility
  ```bash
  brew install sox
  ```

### API Key

- **OpenAI API Key** with Whisper API access
  - Get one at [OpenAI Platform](https://platform.openai.com/api-keys)

### System Permissions

- **Accessibility Permission** for Hammerspoon (required for Fn key detection)
  - Go to: **System Settings** → **Privacy & Security** → **Accessibility**
  - Enable **Hammerspoon**

---

## 📦 Installation

```bash
# 1. Install dependencies
brew install hammerspoon --cask
brew install sox

# 2. Clone repository
git clone https://github.com/Glossardi/Dictator.git ~/Documents/Dictator
cd ~/Documents/Dictator

# 3. Copy files to Hammerspoon
cp *.lua ~/.hammerspoon/

# 4. Grant permissions
# System Settings → Privacy & Security → Accessibility → Enable Hammerspoon
# System Settings → Privacy & Security → Microphone → Enable Hammerspoon

# 5. Reload Hammerspoon (menubar → Reload Config)
```

---

## 🚀 Quick Start

1. **Configure API Key**: Dictator menubar icon → Settings → API Key
   - Get key from: https://platform.openai.com/api-keys
2. **Test**: Open any text editor, hold `Fn` key, speak, release `Fn`
3. **Done**: Text appears automatically!
4. Wait for transcription to appear

---

## ⚙️ Configuration

Access all settings via the menubar icon:

### Settings Menu

- **API Key**: Set your OpenAI API key
- **Language**: Set transcription language (`auto`, `en`, `de`, etc.)
- **Auto-Paste**: Toggle automatic text pasting
- **Use Fn Key (Hold)**: Toggle Fn key as recording hotkey
- **Set Custom Hotkey**: Configure alternative hotkey (when Fn key is disabled)

### Hotkey Options

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

> **Note:** Regardless of auto-paste, the last successful transcription is **always** copied to the clipboard. If auto-paste fails (e.g. focus changed), you can still paste manually with `Cmd+V`.

### Short Tap Behaviour

- Very short hotkey taps (shorter than ~0.4 seconds) are **ignored on purpose**:
  - Recording starts and stops, but **no API call** is made
  - No rate-limit token is consumed
  - The temporary audio file is deleted
- This prevents accidental triggers when you just "tap" the hotkey.

### Copy Last Transcription (Menubar)

- The menubar menu contains an extra entry: **Copy Last Transcription**
- After each successful transcription:
  - The text is stored internally as the "last transcription"
  - The menu entry becomes enabled
- Clicking **Copy Last Transcription**:
  - Copies the last transcription text back to the clipboard
  - Shows a small confirmation toast
- This is useful if you missed the auto-paste or switched windows too quickly.

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

## 🔒 Robustness & Security Features

### Rate Limiting

- **Token Bucket Algorithm**: Prevents exceeding OpenAI API rate limits
- **Default**: 3 requests per 60 seconds (configurable)
- **Automatic**: Checks rate limit before each API call
- **User Feedback**: Shows wait time when rate limit is exceeded

### Hotkey Debouncing

- **Prevents Double-Triggers**: 500ms minimum delay between actions
- **Protects Against**: Accidental double-taps or rapid key presses
- **Smart State Management**: Only allows one operation at a time

### API Retry Logic

- **Exponential Backoff**: Automatically retries on transient failures
- **Handles**:
  - 429 (Rate Limit): Respects `Retry-After` header
  - 5xx (Server Errors): Automatic retry with backoff
  - Network Errors: Connection issues handled gracefully
- **Max Retries**: Up to 3 attempts with increasing delays
- **Jitter**: Random delay added to prevent thundering herd

### Input Validation

- **API Key**: Validates format (must start with `sk-`, minimum length)
- **Audio File**: Checks existence and size (<25MB OpenAI limit)
- **Configuration**: Validates all user inputs before saving
- **State Guards**: Prevents concurrent operations (recording + processing)

### Structured Logging

- **hs.logger Integration**: Professional logging with levels (debug, info, warning, error)
- **Console Output**: View detailed logs in Hammerspoon Console
- **Debugging**: Easy troubleshooting with contextual error messages

---

## 🐛 Troubleshooting

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
5. **File Size**: Recording must be under 25MB (rarely an issue with MP3 compression)
6. Check internet connection
7. API retries automatically (up to 3 attempts with exponential backoff)

**Common Error Messages**:

- `"could not parse multi-part form"` - Fixed in latest version (proper shell escaping)
- `"Network error"` - Check internet connection, DNS resolution
- `"SSL/Certificate error"` - System time may be wrong, or SSL issues
- `"API Error: <message>"` - Check OpenAI status and API key validity

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

````lua
-- Check Fn watcher status
print(fnWatcher and "Fn watcher exists" or "Fn watcher is nil")

-- Check auto-paste setting
print(config.getAutoPaste() and "Auto-Paste ON" or "Auto-Paste OFF")

-- Check use Fn key setting
print(config.getUseFnKey() and "Use Fn Key ON" or "Use Fn Key OFF")
, rate limiting)
- **State management**: Persistent settings via `hs.settings`
- **Error handling**: Comprehensive logging and graceful degradation
- **Event-driven**: Hotkey bindings and UI callbacks
- **Secure by Design**: API key validation, input sanitization, rate limiting
- **Retry Logic**: Exponential backoff with jitter for transient failures
- **Debouncing**: Prevents rapid-fire operations

### Best Practices Implemented
- **DRY**: Reusable modules for each concern
- **KISS**: Simple, clear interfaces
- **LEAN**: Minimal dependencies, efficient resource usage
- **Secure**: No hardcoded secrets, validates all inputs
- **Robust**: Handles edge cases, network failures, rate limit

-- View current processing state
print("Processing: " .. tostring(M.isProcessing)
- Error messages

**Useful Console Commands**:
```lua
-- Check Fn watcher status
print(fnWatcher and "Fn watcher exists" or "Fn watcher is nil")

-- Check auto-paste setting
print(config.getAutoPaste() and "Auto-Paste ON" or "Auto-Paste OFF")

-- Check use Fn key setting
print(config.getUseFnKey() and "Use Fn Key ON" or "Use Fn Key OFF")
````

---

## 🛠️ Development

### Code Structure

- **Modular design**: Separation of concerns (UI, config, audio, API)
- **State management**: Persistent settings via `hs.settings`
- **Error handling**: Comprehensive logging for debugging
- **Event-driven**: Hotkey bindings and UI callbacks

### Testing Locally

1. Make changes to `.lua` files
2. Reload Hammerspoon config
3. Test functionality
4. Check Console for errors
5. Copy to `~/.hammerspoon/` when ready

### Contributing

Contributions welcome! Please:

- Follow existing code style
- Add error handling and logging
- Test thoroughly before submitting
- Update README if adding features

---

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [Hammerspoon](https://www.hammerspoon.org/) – macOS automation framework
- [OpenAI Whisper](https://openai.com/research/whisper) – Speech recognition AI
- [SoX](http://sox.sourceforge.net/) – Audio processing utility
