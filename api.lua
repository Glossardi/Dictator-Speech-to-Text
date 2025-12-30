local M = {}
local config = require("config")
local curl = require("hs.http") -- We might need to use curl via hs.execute if hs.http doesn't support multipart well, but let's try to use a helper or curl command.
-- hs.http does not support multipart/form-data out of the box easily for file uploads without constructing the body manually.
-- It is often easier and more reliable to use `curl` via `hs.execute` or `hs.task` for multipart uploads in Hammerspoon.

function M.transcribe(audioFilePath, callback)
    local apiKey = config.getApiKey()
    if not apiKey then
        print("ERROR: No API Key set")
        if callback then callback(nil, "No API Key set") end
        return
    end

    local url = "https://api.openai.com/v1/audio/transcriptions"
    local model = "whisper-1"
    local language = config.getLanguage()

    -- Construct curl command
    -- -s: silent
    -- -k: insecure (optional, but better to use valid certs, curl usually has them)
    -- --header "Authorization: Bearer $OPENAI_API_KEY"
    -- --header "Content-Type: multipart/form-data"
    -- --form file=@$FILE
    -- --form model=whisper-1
    
    local langArg = ""
    if language and language ~= "auto" then
        langArg = string.format("-F language=%s", language)
    end

    -- Escape paths
    local escapedPath = audioFilePath:gsub('"', '\\"')
    local escapedKey = apiKey:gsub('"', '\\"')

    local command = string.format(
        '/usr/bin/curl -s https://api.openai.com/v1/audio/transcriptions ' ..
        '-H "Authorization: Bearer %s" ' ..
        '-F file="@%s" ' ..
        '-F model="whisper-1" %s',
        escapedKey, escapedPath, langArg
    )

    print("Executing curl command for transcription...")
    print("Audio file: " .. audioFilePath)
    
    hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        print("API Response received. Exit code: " .. exitCode)
        
        if exitCode == 0 then
            -- Log raw response for debugging
            if stdOut and #stdOut > 0 then
                print("Raw API response (first 200 chars): " .. string.sub(stdOut, 1, 200))
            else
                print("WARNING: Empty response from API")
                if callback then callback(nil, "Empty response from API") end
                return
            end
            
            -- Try to decode JSON
            local success, response = pcall(hs.json.decode, stdOut)
            
            if not success then
                print("ERROR: Failed to parse JSON response: " .. tostring(response))
                if callback then callback(nil, "Invalid JSON response from API") end
                return
            end
            
            if response and response.text then
                print("Transcription successful. Text length: " .. #response.text)
                if callback then callback(response.text, nil) end
            elseif response and response.error then
                local errorMsg = response.error.message or "Unknown API error"
                print("ERROR: API returned error: " .. errorMsg)
                if callback then callback(nil, "API Error: " .. errorMsg) end
            else
                print("ERROR: Unknown response format")
                print("Response: " .. hs.inspect(response))
                if callback then callback(nil, "Unknown response format") end
            end
        else
            print("ERROR: Curl command failed with exit code: " .. exitCode)
            if stdErr and #stdErr > 0 then
                print("Stderr: " .. stdErr)
            end
            if stdOut and #stdOut > 0 then
                print("Stdout: " .. stdOut)
            end
            if callback then callback(nil, "Curl error: " .. (stdErr or "Unknown")) end
        end
    end, {"-c", command}):start()
end

return M

