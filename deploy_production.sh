#!/bin/bash
# Deploy Production Correction System to Hammerspoon
# Version 2.0 - High-quality correction

set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying Dictator Production Correction System v2.0"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Check if we're in the right directory
if [ ! -f "config.lua" ]; then
    echo "❌ Error: config.lua not found. Run this script from the Dictator directory."
    exit 1
fi

# Backup existing config
if [ -f "$HOME/.hammerspoon/config.lua" ]; then
    BACKUP_FILE="$HOME/.hammerspoon/config.lua.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📦 Backing up existing config to:"
    echo "   $BACKUP_FILE"
    cp "$HOME/.hammerspoon/config.lua" "$BACKUP_FILE"
    echo
fi

# Copy new config
echo "📋 Copying updated config.lua to ~/.hammerspoon/"
cp -v config.lua "$HOME/.hammerspoon/"
echo

# Copy all lua files (full deployment)
echo "📋 Copying all Lua modules..."
cp -v *.lua "$HOME/.hammerspoon/" 2>/dev/null || true
echo

# Reload Hammerspoon
echo "🔄 Reloading Hammerspoon..."
if command -v hs &> /dev/null; then
    hs -c "hs.reload()"
    echo "✅ Hammerspoon reloaded"
else
    echo "⚠️  Could not auto-reload. Please reload Hammerspoon manually."
fi
echo

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ DEPLOYMENT COMPLETE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "📝 Next steps:"
echo "   1. Verify AI Correction is enabled in menubar"
echo "   2. Recommended model for Groq: openai/gpt-oss-20b"
echo "   3. Test with a short dictation (Cmd+Alt+D)"
echo "   4. Monitor Hammerspoon Console for errors"
echo
echo "📚 Full documentation: README.md"
echo
