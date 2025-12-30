#!/bin/bash

echo "=== Dictator Manual Test Script ==="
echo ""

echo "1. Checking SoX installation..."
if command -v rec &> /dev/null; then
    echo "✓ SoX (rec) is installed at: $(which rec)"
    rec --version 2>&1 | head -1
else
    echo "✗ SoX is NOT installed"
    echo "  Install with: brew install sox"
fi
echo ""

echo "2. Checking curl installation..."
if command -v curl &> /dev/null; then
    echo "✓ curl is installed"
else
    echo "✗ curl is NOT installed"
fi
echo ""

echo "3. Checking Hammerspoon files..."
for file in init.lua config.lua audio.lua api.lua ui.lua utils.lua rate_limiter.lua; do
    if [ -f ~/.hammerspoon/$file ]; then
        echo "✓ $file exists in ~/.hammerspoon/"
    else
        echo "✗ $file is MISSING from ~/.hammerspoon/"
    fi
done
echo ""

echo "4. Testing a simple recording (2 seconds)..."
TEST_FILE="/tmp/dictator_test_$(date +%s).wav"
echo "Recording to: $TEST_FILE"
timeout 2 rec "$TEST_FILE" rate 16k channels 1 2>&1 || echo "Recording test"
if [ -f "$TEST_FILE" ]; then
    SIZE=$(stat -f%z "$TEST_FILE" 2>/dev/null || stat -c%s "$TEST_FILE" 2>/dev/null)
    echo "✓ Recording created: $TEST_FILE (${SIZE} bytes)"
    ls -lh "$TEST_FILE"
    rm -f "$TEST_FILE"
else
    echo "✗ Recording failed"
fi
echo ""

echo "5. Checking Hammerspoon process..."
if pgrep -x "Hammerspoon" > /dev/null; then
    echo "✓ Hammerspoon is running"
else
    echo "✗ Hammerspoon is NOT running"
    echo "  Please start Hammerspoon"
fi
echo ""

echo "=== Test Complete ==="
echo ""
echo "Next steps:"
echo "1. Open Hammerspoon Console (menubar → Console)"
echo "2. Reload config (menubar → Reload Config)"
echo "3. Try using the Fn key or hotkey"
echo "4. Check console for error messages"
