#!/bin/bash

# Quick diagnostic script for Dictator issues

echo "=== Dictator Quick Diagnostics ==="
echo ""

# 1. Check if Hammerspoon is running
if pgrep -x "Hammerspoon" > /dev/null; then
    echo "✓ Hammerspoon is running"
else
    echo "✗ Hammerspoon is NOT running - please start it"
    exit 1
fi

# 2. Check files
echo ""
echo "Checking installation files:"
for file in init.lua config.lua audio.lua api.lua ui.lua utils.lua rate_limiter.lua; do
    if [ -f ~/.hammerspoon/$file ]; then
        SIZE=$(stat -f%z ~/.hammerspoon/$file)
        if [ "$SIZE" -gt 100 ]; then
            echo "  ✓ $file ($SIZE bytes)"
        else
            echo "  ⚠ $file ($SIZE bytes) - suspiciously small!"
        fi
    else
        echo "  ✗ $file - MISSING!"
    fi
done

# 3. Check API key
echo ""
API_KEY=$(defaults read org.hammerspoon.Hammerspoon com.simon.dictator.apiKey 2>/dev/null)
if [ -z "$API_KEY" ]; then
    echo "✗ No API key configured"
    echo ""
    echo "ACTION REQUIRED:"
    echo "1. Click the Dictator menubar icon (🎙️)"
    echo "2. Go to Settings → API Key"
    echo "3. Enter your OpenAI API key (starts with sk-)"
    echo ""
    exit 1
else
    echo "✓ API key is configured"
    if [[ $API_KEY == sk-* ]]; then
        echo "  ✓ Format looks correct (starts with sk-)"
    else
        echo "  ⚠ Format might be wrong (doesn't start with sk-)"
    fi
fi

# 4. Check SoX
echo ""
if command -v rec &> /dev/null; then
    echo "✓ SoX (rec) is installed"
else
    echo "✗ SoX is NOT installed"
    echo "  Run: brew install sox"
fi

# 5. Check system permissions
echo ""
echo "System Permissions Check:"
echo "  ⚠ Cannot auto-check Accessibility permission"
echo "  → Go to: System Settings → Privacy & Security → Accessibility"
echo "  → Ensure Hammerspoon is enabled"

# 6. Try to find console errors
echo ""
echo "Recent Hammerspoon errors (if console.log exists):"
if [ -f ~/Library/Preferences/org.hammerspoon.Hammerspoon.log ]; then
    tail -20 ~/Library/Preferences/org.hammerspoon.Hammerspoon.log | grep -i error | tail -5
else
    echo "  (no console log found)"
fi

echo ""
echo "=== Next Steps ==="
echo ""
echo "1. Open Hammerspoon Console:"
echo "   - Click Hammerspoon menubar icon → Console"
echo ""
echo "2. Reload Hammerspoon:"
echo "   - In Console, type: hs.reload()"
echo "   - Or click menubar → Reload Config"
echo ""
echo "3. Test the app:"
echo "   - Click in any text field"
echo "   - Hold Fn key (or your custom hotkey)"
echo "   - Speak something"
echo "   - Release Fn key"
echo "   - Watch Console for messages"
echo ""
echo "4. Check for specific errors:"
echo "   - 'ERROR:' lines show what went wrong"
echo "   - 'API' errors = API key or network problem"
echo "   - 'Recording' errors = microphone or SoX problem"
echo "   - 'Rate limit' errors = too many requests (wait 60s)"
echo ""
echo "5. Run API test (will use credits!):"
echo "   - cd /Users/Simon/Documents/Dictator"
echo "   - ./test_api.sh"
echo ""
