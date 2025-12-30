#!/bin/bash

echo "=== OpenAI Whisper API Test ==="
echo ""

# Check if API key is configured
API_KEY=$(defaults read org.hammerspoon.Hammerspoon com.simon.dictator.apiKey 2>/dev/null)

if [ -z "$API_KEY" ]; then
    echo "✗ No API key found in Hammerspoon settings"
    echo ""
    echo "To set API key:"
    echo "1. Click Dictator menubar icon"
    echo "2. Settings → API Key"
    echo "3. Enter your OpenAI API key"
    exit 1
fi

echo "✓ API key found (starts with: ${API_KEY:0:7}...)"
echo ""

# Create a test audio file
echo "Creating test audio file..."
TEST_FILE="/tmp/dictator_api_test.wav"

# Record 2 seconds of audio
echo "Recording 2 seconds (speak now or it will be silent)..."
/opt/homebrew/bin/rec -q "$TEST_FILE" rate 16k channels 1 trim 0 2 2>/dev/null

if [ ! -f "$TEST_FILE" ]; then
    echo "✗ Failed to create test audio file"
    exit 1
fi

FILE_SIZE=$(stat -f%z "$TEST_FILE")
echo "✓ Audio file created: ${FILE_SIZE} bytes"
echo ""

# Test API call
echo "Testing OpenAI Whisper API..."
echo "This will consume API credits!"
echo ""

RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
    https://api.openai.com/v1/audio/transcriptions \
    -H "Authorization: Bearer $API_KEY" \
    -F file="@$TEST_FILE" \
    -F model="whisper-1")

HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

echo "HTTP Status Code: $HTTP_CODE"
echo ""

if [ "$HTTP_CODE" = "200" ]; then
    echo "✓ API call successful!"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
elif [ "$HTTP_CODE" = "401" ]; then
    echo "✗ Authentication failed - Invalid API key"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
elif [ "$HTTP_CODE" = "429" ]; then
    echo "✗ Rate limit exceeded"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
else
    echo "✗ API call failed"
    echo ""
    echo "Response:"
    echo "$BODY" | jq . 2>/dev/null || echo "$BODY"
fi

echo ""
echo "Cleaning up test file..."
rm -f "$TEST_FILE"

echo ""
echo "=== Test Complete ==="
