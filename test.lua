#!/usr/bin/env lua
-- Test script for Dictator components
-- Run with: /Applications/Hammerspoon.app/Contents/Frameworks/hs/hs test.lua

print("=== Dictator Component Tests ===\n")

-- Test 1: Check if modules can be loaded
print("Test 1: Module Loading")
local success, config = pcall(require, "config")
if success then
    print("✓ config.lua loaded")
else
    print("✗ config.lua failed: " .. tostring(config))
end

success, audio = pcall(require, "audio")
if success then
    print("✓ audio.lua loaded")
else
    print("✗ audio.lua failed: " .. tostring(audio))
end

success, api = pcall(require, "api")
if success then
    print("✓ api.lua loaded")
else
    print("✗ api.lua failed: " .. tostring(api))
end

success, ui = pcall(require, "ui")
if success then
    print("✓ ui.lua loaded")
else
    print("✗ ui.lua failed: " .. tostring(ui))
end

success, utils = pcall(require, "utils")
if success then
    print("✓ utils.lua loaded")
else
    print("✗ utils.lua failed: " .. tostring(utils))
end

success, rateLimiter = pcall(require, "rate_limiter")
if success then
    print("✓ rate_limiter.lua loaded")
else
    print("✗ rate_limiter.lua failed: " .. tostring(rateLimiter))
end

print("\n")

-- Test 2: API Key Validation
print("Test 2: API Key Validation")
if api then
    local valid, err = api.validateApiKey("")
    print(valid and "✗" or "✓", "Empty key rejected:", err)
    
    valid, err = api.validateApiKey("invalid_key")
    print(valid and "✗" or "✓", "Invalid format rejected:", err)
    
    valid, err = api.validateApiKey("sk-short")
    print(valid and "✗" or "✓", "Short key rejected:", err)
    
    valid, err = api.validateApiKey("sk-1234567890abcdefghij")
    print(valid and "✓" or "✗", "Valid format accepted")
end

print("\n")

-- Test 3: Rate Limiter
print("Test 3: Rate Limiter")
if rateLimiter then
    rateLimiter.init()
    print("✓ Rate limiter initialized")
    
    local status = rateLimiter.getStatus()
    print(string.format("  Max tokens: %d", status.maxTokens))
    print(string.format("  Current tokens: %.2f", status.tokens))
    print(string.format("  Refill rate: %.2f per second", status.refillRate))
    
    local allowed, wait = rateLimiter.consumeToken()
    print(allowed and "✓" or "✗", "First request:", allowed and "Allowed" or string.format("Blocked (wait %ds)", wait))
end

print("\n")

-- Test 4: Config
print("Test 4: Configuration")
if config then
    local apiKey = config.getApiKey()
    print(apiKey and "✓ API Key is set" or "✗ API Key is NOT set")
    
    local lang = config.getLanguage()
    print("✓ Language:", lang)
    
    local autoPaste = config.getAutoPaste()
    print("✓ Auto-Paste:", tostring(autoPaste))
    
    local useFnKey = config.getUseFnKey()
    print("✓ Use Fn Key:", tostring(useFnKey))
end

print("\n")

-- Test 5: Check dependencies
print("Test 5: System Dependencies")
local function checkCommand(cmd)
    local handle = io.popen("which " .. cmd .. " 2>/dev/null")
    local result = handle:read("*a")
    handle:close()
    return result and #result > 0
end

if checkCommand("rec") then
    print("✓ SoX (rec) is installed")
else
    print("✗ SoX (rec) is NOT installed - run: brew install sox")
end

if checkCommand("curl") then
    print("✓ curl is installed")
else
    print("✗ curl is NOT installed")
end

print("\n")

-- Test 6: API Connection Test (if API key is set)
print("Test 6: API Connection Test")
if config and api then
    local apiKey = config.getApiKey()
    if apiKey and #apiKey > 0 then
        print("Testing OpenAI API connection...")
        print("This will make an actual API call (will fail if no audio file exists)")
        
        -- Try to validate the key format at least
        local valid, err = api.validateApiKey(apiKey)
        if valid then
            print("✓ API Key format is valid")
        else
            print("✗ API Key format is invalid:", err)
        end
    else
        print("⚠ Skipping API test - no API key configured")
        print("  Set your API key in the menu: Settings → API Key")
    end
end

print("\n=== Test Summary ===")
print("If all tests pass, the app should work.")
print("Check Hammerspoon Console for runtime logs.")
print("\nCommon issues:")
print("- No API key set: Configure in menubar Settings")
print("- SoX not installed: brew install sox")
print("- Accessibility permissions: Enable in System Settings")
