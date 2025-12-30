-- Debug script to check Dictator state
-- Paste this into Hammerspoon Console

print("=== Dictator Debug Info ===\n")

-- Check if modules are loaded
print("1. Module Status:")
if config then
    print("✓ config module loaded")
    print("  API Key set:", config.getApiKey() and "YES" or "NO")
    print("  Language:", config.getLanguage())
    print("  Auto-Paste:", config.getAutoPaste())
    print("  Use Fn Key:", config.getUseFnKey())
else
    print("✗ config module not loaded")
end

if api then
    print("✓ api module loaded")
    print("  Max retries:", api.MAX_RETRIES)
else
    print("✗ api module not loaded")
end

if audio then
    print("✓ audio module loaded")
    print("  Is recording:", audio.isRecording)
else
    print("✗ audio module not loaded")
end

if ui then
    print("✓ ui module loaded")
    print("  Current status:", ui.currentStatus)
else
    print("✗ ui module not loaded")
end

if rateLimiter then
    print("✓ rateLimiter module loaded")
    local status = rateLimiter.getStatus()
    print(string.format("  Tokens: %.2f / %d", status.tokens, status.maxTokens))
else
    print("✗ rateLimiter module not loaded")
end

print("\n2. Hammerspoon Info:")
print("  Version:", hs.processInfo.version)
print("  Build:", hs.processInfo.buildTime)

print("\n3. File Paths:")
print("  Hammerspoon config:", hs.configdir)
print("  init.lua exists:", hs.fs.attributes(hs.configdir .. "/init.lua") and "YES" or "NO")

print("\n4. Hotkey Status:")
if hotkeyObject then
    print("✓ Custom hotkey bound")
elseif fnWatcher then
    print("✓ Fn key watcher active")
else
    print("✗ No hotkey active")
end

print("\n5. Test API Key Format:")
if config and config.getApiKey() then
    local key = config.getApiKey()
    print("  Length:", #key)
    print("  Starts with 'sk-':", string.sub(key, 1, 3) == "sk-" and "YES" or "NO")
    if api then
        local valid, err = api.validateApiKey(key)
        print("  Validation:", valid and "VALID" or "INVALID: " .. err)
    end
else
    print("  No API key configured!")
end

print("\n=== End Debug Info ===")
print("\nTo test recording:")
print("1. Make sure microphone permissions are granted")
print("2. Click in Hammerspoon Console")
print("3. Hold Fn key (or custom hotkey)")
print("4. Watch for log messages above")
