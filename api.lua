local M = {}
local config = require("config")
local utils = require("utils")

-- Retry configuration
M.MAX_RETRIES = 5
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
        langArg = string.format("-F language=%s", language)
    end

    -- Escape paths and key
    local escapedPath = audioFilePath:gsub('"', '\\"')
    local escapedKey = apiKey:gsub('"', '\\"')

    -- Include verbose headers to capture rate limit info
    local command = string.format(
        '/usr/bin/curl -s -i https://api.openai.com/v1/audio/transcriptions ' ..
        '-H "Authorization: Bearer %s" ' ..
        '-F file="@%s" ' ..
        '-F model="whisper-1" %s',
        escapedKey, escapedPath, langArg
    )

    local attemptLog = attemptNumber > 0 and string.format(" (attempt %d/%d)", attemptNumber + 1, M.MAX_RETRIES) or ""
    print("Executing API request" .. attemptLog .. "...")
    print("Audio file: " .. audioFilePath)
    
    hs.task.new("/bin/sh", function(exitCode, stdOut, stdErr)
        print("API Response received. Exit code: " .. exitCode)
        
        if exitCode == 0 then
            -- Parse headers and body
            local headerEnd = stdOut:find("\r?\n\r?\n")
            local headers = ""
            local body = stdOut
            
            if headerEnd then
                headers = stdOut:sub(1, headerEnd)
                body = stdOut:sub(headerEnd + 1)
            end
            
            -- Log rate limit headers if present
            local rateLimitHeaders = M.parseRateLimitHeaders(headers)
            if next(rateLimitHeaders) then
                print("Rate limit headers: " .. hs.inspect(rateLimitHeaders))
            end
            
            -- Check for HTTP status code in headers
            local statusCode = headers:match("HTTP/[%d%.]+%s+(%d+)")
            if statusCode then
                statusCode = tonumber(statusCode)
                print("HTTP Status: " .. statusCode)
                
                -- Handle 429 Rate Limit
                if statusCode == 429 then
                    local retryAfter = headers:match("retry%-after:%s*(%d+)")
                    local delay = M.calculateRetryDelay(attemptNumber, retryAfter)
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
                print("WARNING: Empty response body from API")
                if callback then callback(nil, "Empty response from API") end
                return
            end
            
            -- Try to decode JSON
            local success, response = pcall(hs.json.decode, body)
            
            if not success then
                print("ERROR: Failed to parse JSON response: " .. tostring(response))
                print("Raw response (first 500 chars): " .. string.sub(body, 1, 500))
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
            if stdErr and #stdErr > 0 then
                print("Stderr: " .. stdErr)
            end
            if stdOut and #stdOut > 0 then
                print("Stdout: " .. stdOut)
            end
            
            -- Retry on network errors
            local delay = M.calculateRetryDelay(attemptNumber, nil)
            print(string.format("Network error. Retrying in %.1f seconds...", delay))
            
            hs.timer.doAfter(delay, function()
                M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber + 1, callback)
            end)
        end
    end, {"-c", command}):start()
end

return M

