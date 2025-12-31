local M = {}
local config = require("config")
local utils = require("utils")

-- Retry configuration
M.MAX_RETRIES = 3
M.INITIAL_RETRY_DELAY = 1  -- seconds
M.MAX_RETRY_DELAY = 60  -- seconds

-- Validate API key format (basic check)
function M.validateApiKey(apiKey)
    if not apiKey or apiKey == "" then
        return false, "API key is empty"
    end
    
    -- OpenAI API keys start with 'sk-' and are at least 20 characters
    if not string.match(apiKey, "^sk%-") then
        return false, "Invalid API key format (should start with 'sk-')"
    end
    
    if #apiKey < 20 then
        return false, "API key too short"
    end
    
    return true, nil
end

-- Validate audio file
function M.validateAudioFile(filePath)
    if not filePath or filePath == "" then
        return false, "No file path provided"
    end
    
    if not utils.file_exists(filePath) then
        return false, "Audio file does not exist"
    end
    
    -- Check file size (OpenAI Whisper limit: 25MB)
    local fileSize = utils.get_file_size(filePath)
    if not fileSize then
        return false, "Cannot determine file size"
    end
    
    local maxSize = 25 * 1024 * 1024  -- 25MB in bytes
    if fileSize > maxSize then
        return false, string.format("File too large (%.2f MB, max 25 MB)", fileSize / (1024 * 1024))
    end
    
    return true, nil
end

-- Parse rate limit headers from curl response
function M.parseRateLimitHeaders(curlOutput)
    local headers = {}
    
    -- Look for rate limit headers in curl output
    for line in curlOutput:gmatch("[^\r\n]+") do
        local key, value = line:match("^x%-ratelimit%-([^:]+):%s*(.+)$")
        if key and value then
            headers[key] = value
        end
    end
    
    return headers
end

-- Calculate retry delay with exponential backoff and jitter
function M.calculateRetryDelay(attemptNumber, retryAfter)
    if retryAfter and tonumber(retryAfter) then
        return math.min(tonumber(retryAfter), M.MAX_RETRY_DELAY)
    end
    
    -- Exponential backoff: delay = initial * (2 ^ attempt)
    local delay = M.INITIAL_RETRY_DELAY * (2 ^ attemptNumber)
    
    -- Add jitter (random 0-1 seconds) to avoid thundering herd
    local jitter = math.random()
    delay = delay + jitter
    
    -- Cap at max delay
    return math.min(delay, M.MAX_RETRY_DELAY)
end

-- Transcribe with retry logic
function M.transcribe(audioFilePath, callback)
    local apiKey = config.getApiKey()
    
    -- Validate API key
    local valid, err = M.validateApiKey(apiKey)
    if not valid then
        print("ERROR: " .. err)
        if callback then callback(nil, err) end
        return
    end
    
    -- Validate audio file
    valid, err = M.validateAudioFile(audioFilePath)
    if not valid then
        print("ERROR: " .. err)
        if callback then callback(nil, err) end
        return
    end

    -- Start transcription with retry logic
    M.transcribeWithRetry(audioFilePath, apiKey, 0, callback)
end

-- Internal function to handle retries
function M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber, callback)
    if attemptNumber >= M.MAX_RETRIES then
        local errorMsg = string.format("Max retries (%d) exceeded", M.MAX_RETRIES)
        print("ERROR: " .. errorMsg)
        if callback then callback(nil, errorMsg) end
        return
    end
    
    local url = "https://api.openai.com/v1/audio/transcriptions"
    local language = config.getLanguage()

    local langArg = ""
    if language and language ~= "auto" then
        -- language codes are simple (en,de,auto), no complex escaping needed
        langArg = string.format("-F language=%s", language)
    end

    -- Properly escape shell arguments using single quotes
    -- For paths and headers, we use single quotes which prevent all shell expansion
    -- We only need to handle single quotes within the strings by escaping them
    local function shellEscape(str)
        -- Replace single quotes with '\'' (end quote, escaped quote, start quote)
        return "'" .. str:gsub("'", "'\\''") .. "'"
    end

    local authHeader = shellEscape("Authorization: Bearer " .. apiKey)
    local fileArg = shellEscape("file=@" .. audioFilePath)

    -- Use -w flag to get HTTP status code separately from body
    -- Use proper @ syntax for file upload, let curl auto-generate Content-Type
    -- Robustness flags only (no low-level TCP tuning which caused timeouts on some networks):
    --   --compressed: Enable HTTP compression
    --   --connect-timeout 10 / --max-time 60: Ensure we never hang forever
    local command = string.format(
        '/usr/bin/curl -s -w "\\nHTTP_STATUS:%%{http_code}" ' ..
        '--compressed ' ..
        '--connect-timeout 10 --max-time 60 ' ..
        '%s ' ..
        '-H %s ' ..
        '-F %s ' ..
        '-F model=whisper-1 %s',
        url, authHeader, fileArg, langArg
    )

    local attemptLog = attemptNumber > 0 and string.format(" (attempt %d/%d)", attemptNumber + 1, M.MAX_RETRIES) or ""
    print("Executing API request" .. attemptLog .. "...")
    print("Audio file: " .. audioFilePath)
    print("File size: " .. string.format("%.2f KB", (utils.get_file_size(audioFilePath) or 0) / 1024))
    print("Command: " .. command)
    
    hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        print("API Response received. Exit code: " .. exitCode)
        
        if exitCode == 0 then
            -- Extract HTTP status code from end of response
            local statusCode = nil
            local body = stdOut
            
            local statusMatch = stdOut:match("\nHTTP_STATUS:(%d+)$")
            if statusMatch then
                statusCode = tonumber(statusMatch)
                -- Remove status line from body
                body = stdOut:gsub("\nHTTP_STATUS:%d+$", "")
                print("HTTP Status: " .. statusCode)
            else
                print("WARNING: Could not extract HTTP status code")
            end
            
            -- Handle error status codes
            if statusCode then
                -- Handle 429 Rate Limit
                if statusCode == 429 then
                    local delay = M.calculateRetryDelay(attemptNumber, nil)
                    print(string.format("Rate limit hit (429). Retrying in %.1f seconds...", delay))
                    
                    hs.timer.doAfter(delay, function()
                        M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber + 1, callback)
                    end)
                    return
                end
                
                -- Handle 5xx Server Errors
                if statusCode >= 500 and statusCode < 600 then
                    local delay = M.calculateRetryDelay(attemptNumber, nil)
                    print(string.format("Server error (%d). Retrying in %.1f seconds...", statusCode, delay))
                    
                    hs.timer.doAfter(delay, function()
                        M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber + 1, callback)
                    end)
                    return
                end
            end
            
            -- Parse JSON body
            if not body or #body == 0 then
                print("ERROR: Empty response body from API")
                if callback then callback(nil, "Empty response from API") end
                return
            end
            
            -- Try to decode JSON
            local success, response = pcall(hs.json.decode, body)
            
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
                local errorType = response.error.type or "unknown"
                print(string.format("ERROR: API returned error [%s]: %s", errorType, errorMsg))
                
                -- Retry on certain error types
                if errorType == "server_error" or errorType == "requests" then
                    local delay = M.calculateRetryDelay(attemptNumber, nil)
                    print(string.format("Retryable error. Retrying in %.1f seconds...", delay))
                    
                    hs.timer.doAfter(delay, function()
                        M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber + 1, callback)
                    end)
                    return
                end
                
                if callback then callback(nil, "API Error: " .. errorMsg) end
            else
                print("ERROR: Unknown response format")
                print("Response: " .. hs.inspect(response))
                if callback then callback(nil, "Unknown response format") end
            end
        else
            -- Curl command failed
            print("ERROR: Curl command failed with exit code: " .. exitCode)
            print("Command was: " .. command)
            if stdOut and #stdOut > 0 then
                print("Stdout: " .. stdOut)
            end
            if stdErr and #stdErr > 0 then
                print("Stderr: " .. stdErr)
            end
            
            -- Check for common curl errors
            if stdErr:match("Could not resolve host") then
                print("ERROR: Network connectivity issue - cannot reach OpenAI API")
                if callback then callback(nil, "Network error: Cannot reach OpenAI API") end
                return
            elseif stdErr:match("SSL") or stdErr:match("certificate") then
                print("ERROR: SSL/Certificate error")
                if callback then callback(nil, "SSL/Certificate error") end
                return
            elseif stdErr:match("multipart") or stdErr:match("boundary") then
                print("ERROR: Multipart form data error - check file path and curl syntax")
                if callback then callback(nil, "Multipart form parsing error") end
                return
            end
            
            -- Retry on network errors (but not on validation/auth errors)
            if attemptNumber < M.MAX_RETRIES - 1 then
                local delay = M.calculateRetryDelay(attemptNumber, nil)
                print(string.format("Network error. Retrying in %.1f seconds...", delay))
                
                hs.timer.doAfter(delay, function()
                    M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber + 1, callback)
                end)
            else
                if callback then callback(nil, "Network error after " .. M.MAX_RETRIES .. " attempts") end
            end
        end
    end, {"-c", command}):start()
end

return M

