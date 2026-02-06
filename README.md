# Dictator: High-Performance Voice-to-Text for macOS

**Dictator** is a lightweight macOS menubar application that provides near-instant speech-to-text transcription using OpenAI's Whisper API. Powered by [Hammerspoon](https://www.hammerspoon.org/), it offers a seamless workflow for dictating text directly into any application.

[![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
[![Hammerspoon](https://img.shields.io/badge/Hammerspoon-0.9.97+-green.svg)](https://www.hammerspoon.org/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

---

## 🚀 Essentials

Dictator converts speech to text with professional accuracy using the latest Whisper AI models. It sits quietly in your menubar, ready to transcribe your thoughts the moment you press a key.

### Key Benefits:
- **Fast & Reliable**: Near-instant transcription via Groq or OpenAI.
- **BYOK (OpenAI Standard)**: Support for any OpenAI-compatible API provider.
- **Privacy First**: Audio is processed only by your chosen API provider.
- **Smart Formatting**: Optional AI-powered grammar and punctuation refinement.
- **Native Experience**: A sleek macOS menubar app that works with any text field.

---

## 📦 Installation

To get started, ensure you have [Hammerspoon](https://www.hammerspoon.org/) and [SoX](https://sourceforge.net/projects/sox/) installed:
`brew install --cask hammerspoon sox`

```bash
# 1. Clone the repository
git clone https://github.com/Glossardi/Dictator-Speech-to-Text.git ~/Documents/Dictator

# 2. Run the installer
cd ~/Documents/Dictator
./install.sh
```

*The installer will guide you through the initial setup, including API key configuration and system permissions.*

---

## 🔄 Updating

Stay current with the latest transcription models and features:

### Method 1: Menubar (Recommended)
Click the Dictator icon (🎙️) and select **Update Dictator...**. This handles everything automatically.

### Method 2: Terminal
```bash
cd ~/Documents/Dictator
make update
```

---

## ⌨️ Quick Start

1. **Grant Permissions**: Ensure Hammerspoon has **Accessibility** and **Microphone** access in *System Settings > Privacy & Security*.
2. **Setup API**: Click the 🎙️ icon > **Settings** > **Set API Key**.
3. **Dictate**: Hold the `Fn` key, speak, and release to transcribe directly into your focused app.

---

## �️ Manual Override

If the automated script fails or you prefer full control, use these commands to manually install or update:

```bash
# 1. Install dependencies
brew install --cask hammerspoon sox

# 2. Copy application files
mkdir -p ~/.hammerspoon
cp -v ~/Documents/Dictator/*.lua ~/.hammerspoon/

# 3. Reload Hammerspoon
# Click icon (🎙️ or 🔨) > Reload Config
```

---

## �🔧 Features at a Glance

- **🎙️ Hold-to-Record**: Minimalist workflow with customizable hotkeys.
- **⚡ Performance**: Optimized for Groq (transcription often under 500ms).
- **🔑 BYOK**: Compatible with all OpenAI-standard API providers.
- **🎯 Precision**: Support for custom technical glossaries to avoid mistakes.
- **🌍 Global**: Multi-language support via Whisper-v3 Large models.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
