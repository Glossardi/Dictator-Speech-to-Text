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
- **✨ AI Correction (Optional)**: Post-process transcription with a fast LLM (default: `gpt-4o-mini`) for punctuation/grammar/paragraphs
- **📋 Auto-Paste**: Automatically paste transcribed text (toggle on/off)
- **⚙️ Configurable**: Set API key, custom hotkeys, language, and auto-paste behavior
- **🎯 Minimal UI**: Clean menubar icon showing current status (🎙️ Idle, 🔴 Recording, ⏳ Processing, 🤖 AI)
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
# Create the Hammerspoon config directory (if needed) and copy the Lua files from this repo:
mkdir -p ~/.hammerspoon && cp -v ~/Documents/Dictator/*.lua ~/.hammerspoon/

# Optional: make a quick backup of existing Hammerspoon scripts before overwriting
# mkdir -p ~/.hammerspoon_backup && cp -v ~/.hammerspoon/*.lua ~/.hammerspoon_backup/

# 4. Grant permissions
# System Settings → Privacy & Security → Accessibility → Enable Hammerspoon
# System Settings → Privacy & Security → Microphone → Enable Hammerspoon

# 5. Reload Hammerspoon (menubar → Reload Config)
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

- **API Key**: Set your OpenAI API key
- **Language**: Set transcription language (`auto`, `en`, `de`, etc.)
- **Auto-Paste**: Toggle automatic text pasting
- **Enable AI Correction**: Toggle post-processing of the transcription (default: OFF to avoid extra cost)
- **Correction Settings**: Configure model + system prompt (only enabled when AI correction is ON)
- **Use Fn Key (Hold)**: Toggle Fn key as recording hotkey
- **Set Custom Hotkey**: Configure alternative hotkey (when Fn key is disabled)

### AI Correction (Optional)

When enabled, Dictator will run an extra step after Whisper:

1. Whisper returns the raw transcription
2. A Chat Completions call corrects punctuation/grammar and adds paragraphs
3. The corrected text is pasted/copied

**Fail-open behavior:** If the correction call fails (network, API error, rate limit), Dictator will still paste/copy the original Whisper text so you never lose data.

#### Verifying your System Prompt is actually used

If you suspect that changing the **Correction System Prompt** in the menubar settings has no effect, you can verify it via the Hammerspoon Console logs.

1. Enable **Enable AI Correction** in the Dictator menubar.
2. Set **Correction Settings → Set System Prompt...** to your desired prompt.
3. Trigger a transcription (record > release).
4. Open **Hammerspoon → Console** and look for the correction request logs:

- `Executing correction request...`
- `System prompt: <N> chars`
- `System prompt preview: ...`
- `Correction response received (http=<status>) in <seconds>s`

If you see these lines, the system prompt is being loaded from `hs.settings` and sent as a `role="system"` message to the Chat Completions endpoint.

**Important:** Because Dictator is fail-open, a fast correction failure (e.g. invalid model, quota, auth issues) will fall back to the raw Whisper transcript, which can look like “correction didn’t run”. In that case, you’ll also see a log line like:

- `Correction API error (http=<status>) ...`

Some models reject non-default sampling parameters (e.g. `temperature`). If that happens, Dictator automatically retries the correction once without `temperature` before falling back.

Fix the underlying API/model issue, then retry.

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
