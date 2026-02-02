-- api.lua
-- OpenAI API integration for Whisper transcription and AI correction
-- Handles retries, error handling, and model compatibility (temperature auto-retry)

local M = {}
local config = require("config")
local utils = require("utils")

-- Retry configuration
M.MAX_RETRIES = 3
M.INITIAL_RETRY_DELAY = 1  -- seconds
M.MAX_RETRY_DELAY = 60  -- seconds

-- Task management: prevent garbage collection of hs.task objects
-- which can cause blocking issues in Hammerspoon
M.activeTasks = {}

-- Provider detection helpers
function M.isCloudflareProvider(baseUrl)
    if not baseUrl then return false end
    return baseUrl:lower():find("cloudflare.com", 1, true) ~= nil
 end

-- Convert audio file to base64 for Cloudflare Workers AI
function M.audioFileToBase64(filePath)
    local file = io.open(filePath, "rb")
    if not file then
        return nil, "Cannot open audio file"
    end
    
    local content = file:read("*all")
    file:close()
    
    if not content or #content == 0 then
        return nil, "Empty audio file"
    end
    
    -- Use openssl base64 encoding via command line for reliability
    local encodedFile = os.tmpname() .. ".b64"
    local cmd = string.format("/usr/bin/openssl base64 -in %s -out %s", 
        hs.execute("printf %q " .. filePath), 
        hs.execute("printf %q " .. encodedFile))
    
    local exitCode = os.execute(cmd)
    if exitCode ~= 0 and exitCode ~= true then
        os.remove(encodedFile)
        return nil, "Failed to encode audio to base64"
    end
    
    local encodedFileHandle = io.open(encodedFile, "r")
    if not encodedFileHandle then
        os.remove(encodedFile)
        return nil, "Cannot read encoded file"
    end
    
    local base64Content = encodedFileHandle:read("*all")
    encodedFileHandle:close()
    os.remove(encodedFile)
    
    -- Remove newlines from base64 encoding
    base64Content = base64Content:gsub("[\n\r]", "")
    
    return base64Content, nil
 end

-- Validate API key format (basic check)
-- Supports multiple providers: OpenAI (sk-...), DeepInfra, and others
function M.validateApiKey(apiKey)
    if not apiKey or apiKey == "" then
        return false, "API key is empty"
    end
    
    -- Basic length check - most API keys are at least 20 characters
    if #apiKey < 20 then
        return false, "API key too short (minimum 20 characters)"
    end
    
    -- Flexible validation: allow various formats for different providers
    -- OpenAI: sk-...
    -- DeepInfra: different format
    -- Other providers: may have different formats
    -- We just check for reasonable length and non-empty
    
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
    local apiKey = config.getTranscriptionApiKey()
    
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

-- Correct transcribed text using Chat Completions (optional post-processing)
function M.correctText(text, callback)
    local apiKey = config.getCorrectionApiKey()

    local valid, err = M.validateApiKey(apiKey)
    if not valid then
        print("ERROR: " .. err)
        if callback then callback(nil, err) end
        return
    end

    if type(text) ~= "string" or text == "" then
        if callback then callback(nil, "No text to correct") end
        return
    end

    -- includeTemperature=true by default; some models reject non-default temperatures
    M.correctTextWithRetry(text, apiKey, 0, callback, true)
end

function M.correctTextWithRetry(text, apiKey, attemptNumber, callback, includeTemperature)
    if attemptNumber >= M.MAX_RETRIES then
        local errorMsg = string.format("Max retries (%d) exceeded", M.MAX_RETRIES)
        print("ERROR: " .. errorMsg)
        if callback then callback(nil, errorMsg) end
        return
    end

    if includeTemperature == nil then includeTemperature = true end

    local baseUrl = config.getCorrectionApiBaseUrl()
    local model = config.getCorrectionModel()
    local systemPrompt = config.getCorrectionSystemPrompt()
    local isCloudflare = M.isCloudflareProvider(baseUrl)
    
    -- Build URL based on provider
    local url
    if isCloudflare then
        -- Cloudflare Workers AI: use /v1/chat/completions endpoint
        url = baseUrl:gsub("/v1/openai$", "") .. "/v1/chat/completions"
    else
        url = baseUrl .. "/chat/completions"
    end

    -- Debug visibility: confirm which prompt is actually used at runtime.
    -- (Avoid logging user text; only log prompt metadata + a short preview.)
    local promptLen = type(systemPrompt) == "string" and #systemPrompt or 0
    local promptPreview = ""
    if type(systemPrompt) == "string" and systemPrompt ~= "" then
        promptPreview = systemPrompt:gsub("%s+", " "):sub(1, 160)
    end

    local payload = {
        model = model,
        messages = {
            { role = "system", content = systemPrompt },
            { role = "user", content = "### TRANSCRIPT START ###\n" .. text .. "\n### TRANSCRIPT END ###" }
        }
    }

    -- Preferred parameters for correction when supported by the model.
    -- Some models only support default parameters; in that case we omit them.
    if includeTemperature then
        payload.temperature = 0.2           -- Optimal for code/technical tasks (0.1-0.3 range)
        payload.top_p = 0.95                 -- Default for deterministic tasks
        payload.frequency_penalty = 0.4      -- Prevents word repetition (e.g. "um um um")
        payload.presence_penalty = 0.0       -- Not needed for text cleaning
        payload.max_tokens = 2048            -- Standard for longer inputs
    end

    local jsonBody = hs.json.encode(payload)

    local args = {
        "-s",
        "-w", "\nHTTP_STATUS:%{http_code}",
        "--compressed",
        "--connect-timeout", "10",
        "--max-time", "15",  -- Timeout reduced for faster fail-open
        "-H", "Authorization: Bearer " .. apiKey,
        "-H", "Content-Type: application/json",
        "-d", jsonBody,
        url
    }

    local attemptLog = attemptNumber > 0 and string.format(" (attempt %d/%d)", attemptNumber + 1, M.MAX_RETRIES) or ""
    local provider = isCloudflare and "Cloudflare Workers AI" or "OpenAI-compatible"
    print("Executing correction request" .. attemptLog .. "...")
    print("Provider: " .. provider)
    print("Model: " .. tostring(model))
    print(string.format("System prompt: %d chars", promptLen))
    if promptPreview ~= "" then
        local suffix = (promptLen > 160) and "..." or ""
        print("System prompt preview: " .. promptPreview .. suffix)
    end

    local requestStart = hs.timer.secondsSinceEpoch()

    local task = hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        -- Wrap entire callback in pcall to prevent errors from hanging the app
        local success, callbackError = pcall(function()
            -- Remove from active tasks
            for i, t in ipairs(M.activeTasks) do
                if t == task then
                    table.remove(M.activeTasks, i)
                    break
                end
            end
            local elapsed = hs.timer.secondsSinceEpoch() - requestStart
            if exitCode == 0 then
            -- curl appends our status trailer after a real newline. Normalize CRLF just in case.
            local normalized = (stdOut or ""):gsub("\r\n", "\n")
            local statusMatch = normalized:match("\nHTTP_STATUS:(%d+)%s*$")
            local statusCode = statusMatch and tonumber(statusMatch) or nil
            local body = normalized:gsub("\nHTTP_STATUS:%d+%s*$", "")

            print(string.format("Correction response received (http=%s) in %.2fs", tostring(statusCode), elapsed))

            if statusCode == 429 then
                local delay = M.calculateRetryDelay(attemptNumber, nil)
                print(string.format("Rate limit hit (429). Retrying in %.1f seconds...", delay))
                hs.timer.doAfter(delay, function()
                    M.correctTextWithRetry(text, apiKey, attemptNumber + 1, callback)
                end)
                return
            end

            if statusCode and statusCode >= 500 and statusCode < 600 then
                local delay = M.calculateRetryDelay(attemptNumber, nil)
                print(string.format("Server error (%d). Retrying in %.1f seconds...", statusCode, delay))
                hs.timer.doAfter(delay, function()
                    M.correctTextWithRetry(text, apiKey, attemptNumber + 1, callback)
                end)
                return
            end

            if not body or #body == 0 then
                if callback then callback(nil, "Empty response from correction API") end
                return
            end

            local success, response = pcall(hs.json.decode, body)
            if not success then
                if callback then callback(nil, "Invalid JSON response from correction API") end
                return
            end

            if response and response.error then
                -- OpenAI/DeepInfra error format
                local errorMsg = response.error.message or "Unknown API error"
                print(string.format("Correction API error (http=%s) after %.2fs: %s", tostring(statusCode), elapsed, tostring(errorMsg)))

                -- Professional robustness: some models reject non-default temperatures.
                -- If we see that specific class of error, retry once without temperature.
                if statusCode == 400 and includeTemperature and type(errorMsg) == "string" then
                    local lower = errorMsg:lower()
                    if lower:find("temperature", 1, true) and (lower:find("only the default", 1, true) or lower:find("does not support", 1, true) or lower:find("unsupported", 1, true)) then
                        print("Correction: model does not support temperature parameter; retrying without temperature...")
                        M.correctTextWithRetry(text, apiKey, attemptNumber, callback, false)
                        return
                    end
                end

                if callback then callback(nil, "API Error: " .. errorMsg) end
                return
            elseif response and response.success == false and response.errors then
                -- Cloudflare error format
                local errorMsg = "Unknown Cloudflare error"
                if response.errors[1] and response.errors[1].message then
                    errorMsg = response.errors[1].message
                    local errorCode = response.errors[1].code or "unknown"
                    print(string.format("Correction Cloudflare API error (http=%s) after %.2fs [%s]: %s", tostring(statusCode), elapsed, tostring(errorCode), errorMsg))
                end

                if callback then callback(nil, "Cloudflare API Error: " .. errorMsg) end
                return
            end

            local content = nil
            -- OpenAI/DeepInfra format: choices[0].message.content
            if response and response.choices and response.choices[1] and response.choices[1].message then
                content = response.choices[1].message.content
            -- Cloudflare format: result.response (if they use their wrapper format)
            elseif response and response.success == true and response.result then
                if type(response.result) == "table" and response.result.response then
                    content = response.result.response
                elseif type(response.result) == "string" then
                    content = response.result
                end
            end

            if type(content) == "string" and content ~= "" then
                -- Trim outer whitespace without touching internal formatting
                content = content:gsub("^%s+", ""):gsub("%s+$", "")
                if callback then callback(content, nil) end
            else
                if callback then callback(nil, "Unknown correction response format") end
            end
        else
            if stdErr and #stdErr > 0 then
                print(string.format("ERROR: Curl correction request failed after %.2fs: %s", elapsed, stdErr))
            else
                print(string.format("ERROR: Curl correction request failed after %.2fs (exitCode=%s)", elapsed, tostring(exitCode)))
            end

            if attemptNumber < M.MAX_RETRIES - 1 then
                local delay = M.calculateRetryDelay(attemptNumber, nil)
                print(string.format("Correction network error. Retrying in %.1f seconds...", delay))
                hs.timer.doAfter(delay, function()
                    M.correctTextWithRetry(text, apiKey, attemptNumber + 1, callback)
                end)
            else
                if callback then callback(nil, "Correction network error after " .. M.MAX_RETRIES .. " attempts") end
            end
        end
        end) -- End of pcall
        
        -- Handle pcall errors
        if not success then
            print("ERROR: Critical error in correction callback: " .. tostring(callbackError))
            -- Ensure callback is called with error to prevent app from hanging
            if callback then 
                pcall(callback, nil, "Internal error: " .. tostring(callbackError))
            end
        end
    end, args)
    
    -- Persist task to prevent GC-related blocking
    table.insert(M.activeTasks, task)
    task:start()
end

-- Internal function to handle retries
function M.transcribeWithRetry(audioFilePath, apiKey, attemptNumber, callback)
    if attemptNumber >= M.MAX_RETRIES then
        local errorMsg = string.format("Max retries (%d) exceeded", M.MAX_RETRIES)
        print("ERROR: " .. errorMsg)
        if callback then callback(nil, errorMsg) end
        return
    end
    
    local baseUrl = config.getTranscriptionApiBaseUrl()
    local model = config.getTranscriptionModel()
    local language = config.getLanguage()
    local glossary = config.getGlossary()
    local isCloudflare = M.isCloudflareProvider(baseUrl)
    local isOpenAIOfficial = baseUrl:lower():find("api.openai.com", 1, true) ~= nil
    
    local url, args, jsonBody
    
    local tempFile = nil  -- Track temp file for cleanup
    
    if isCloudflare then
        -- Cloudflare Workers AI uses REST API with base64-encoded audio
        url = baseUrl:gsub("/v1/openai$", "") .. "/ai/run/" .. model
        
        -- Convert audio to base64
        local base64Audio, err = M.audioFileToBase64(audioFilePath)
        if not base64Audio then
            print("ERROR: " .. (err or "Failed to encode audio"))
            if callback then callback(nil, err or "Failed to encode audio") end
            return
        end
        
        -- Build JSON payload for Cloudflare
        local payload = {
            audio = base64Audio,
            temperature = 0
        }
        
        -- Add optional parameters
        if language and language ~= "auto" then
            payload.language = language
        end
        
        if glossary and glossary ~= "" then
            -- Truncate glossary to ~224 tokens/1000 chars for API compatibility
            local truncatedGlossary = glossary
            if #truncatedGlossary > 1000 then
                truncatedGlossary = truncatedGlossary:sub(1, 1000)
            end
            payload.initial_prompt = truncatedGlossary
        end
        
        jsonBody = hs.json.encode(payload)
        
        -- Write JSON to temp file to avoid command-line length limits (large base64 strings)
        tempFile = os.tmpname()
        local file = io.open(tempFile, "w")
        if not file then
            print("ERROR: Cannot create temporary file for request")
            if callback then callback(nil, "Cannot create temporary file") end
            return
        end
        file:write(jsonBody)
        file:close()
        
        -- Build curl arguments for JSON request (use @file to avoid arg length limits)
        args = {
            "-s",
            "-w", "\nHTTP_STATUS:%{http_code}",
            "--compressed",
            "--connect-timeout", "10",
            "--max-time", "90",  -- Cloudflare may take longer
            url,
            "-H", "Authorization: Bearer " .. apiKey,
            "-H", "Content-Type: application/json",
            "-d", "@" .. tempFile
        }
    else
        -- OpenAI/compatible providers use multipart form-data
        url = baseUrl .. "/audio/transcriptions"
        
        args = {
            "-s",
            "-w", "\nHTTP_STATUS:%{http_code}",
            "--compressed",
            "--connect-timeout", "10",
            "--max-time", "90",  -- Increased from 60s to 90s for longer audio files
            url,
            "-H", "Authorization: Bearer " .. apiKey,
            "-F", "file=@" .. audioFilePath,
            "-F", "model=" .. model,
            "-F", "temperature=0"  -- Force deterministic output for all compatible providers
        }
        
        -- Add provider-specific parameters
        -- Only OpenAI API (api.openai.com) supports response_format=verbose_json
        isOpenAIOfficial = baseUrl:lower():find("api.openai.com", 1, true) ~= nil
        
        if isOpenAIOfficial then
            -- OpenAI supports verbose_json for detailed segment data
            table.insert(args, "-F")
            table.insert(args, "response_format=verbose_json")
        end

        if language and language ~= "auto" then
            table.insert(args, "-F")
            table.insert(args, "language=" .. language)
        end
        
        if glossary and glossary ~= "" then
            -- Truncate glossary to ~200 words / 1000 chars to avoid Whisper API limits/issues
            local truncatedGlossary = glossary
            if #truncatedGlossary > 1000 then
                truncatedGlossary = truncatedGlossary:sub(1, 1000)
                print("WARNING: Glossary truncated for API request (too long)")
            end
            table.insert(args, "-F")
            table.insert(args, "prompt=" .. truncatedGlossary)
        end
    end

    local attemptLog = attemptNumber > 0 and string.format(" (attempt %d/%d)", attemptNumber + 1, M.MAX_RETRIES) or ""
    local provider = isCloudflare and "Cloudflare Workers AI" or "OpenAI-compatible"
    print("Executing API request" .. attemptLog .. "...")
    print("Provider: " .. provider)
    print("API Base URL: " .. baseUrl)
    print("Model: " .. model)
    print("Audio file: " .. audioFilePath)
    print("File size: " .. string.format("%.2f KB", (utils.get_file_size(audioFilePath) or 0) / 1024))
    if glossary and glossary ~= "" then
        local glossaryPreview = glossary:sub(1, 100)
        if #glossary > 100 then
            glossaryPreview = glossaryPreview .. "..."
        end
        print("Glossary: " .. glossaryPreview .. " (" .. #glossary .. " chars)")
    end
    -- Store command for error logging (simplified for Cloudflare JSON requests)
    local commandForLog
    if isCloudflare then
        commandForLog = "/usr/bin/curl -s -w \\nHTTP_STATUS:%{http_code} --compressed " .. url .. " -H 'Authorization: Bearer <redacted>' -H 'Content-Type: application/json' -d '{...}'"
    else
        -- Show real timeout in logs
        commandForLog = "/usr/bin/curl -s -w \\nHTTP_STATUS:%{http_code} --compressed --connect-timeout 10 --max-time 90 " .. url .. " -H 'Authorization: Bearer <redacted>' -F 'file=@" .. audioFilePath .. "' -F model=" .. model .. " " .. (language and language ~= "auto" and (" -F language=" .. language) or "") .. (glossary and glossary ~= "" and (" -F prompt='" .. glossary:sub(1, 64) .. "...'") or "")
    end
    print("Command: " .. commandForLog)
    
    local task = hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        -- Wrap entire callback in pcall to prevent errors from hanging the app
        local success, callbackError = pcall(function()
            -- Clean up temp file immediately
            if tempFile then
                os.remove(tempFile)
            end
            
            -- Remove task from active tasks to allow cleanup
            for i, t in ipairs(M.activeTasks) do
                if t == task then
                    table.remove(M.activeTasks, i)
                    break
                end
            end
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
            
            -- Debug: Log response body length (to detect provider-side truncation)
            local bodyLength = #body
            if bodyLength > 5000 then
                print("DEBUG: Response body length: " .. bodyLength .. " bytes (may indicate large text response)")
            elseif bodyLength < 100 then
                print("WARNING: Response body very short: " .. bodyLength .. " bytes")
            end
            
            -- Try to decode JSON
            local success, response = pcall(hs.json.decode, body)
            
            if not success then
                print("ERROR: Failed to parse JSON response: " .. tostring(response))
                if callback then callback(nil, "Invalid JSON response from API") end
                return
            end
            
            -- Check for successful transcription (OpenAI format)
            if response and response.text then
                local text = response.text
                local isHallucination = false
                
                -- Detect "Prompt Reflection" Hallucinations:
                -- If the output is just a subset or exact match of the glossary, and audio was near-silent/short,
                -- it is almost certainly a hallucination.
                if glossary and #glossary > 5 and #text > 3 then
                    local cleanText = text:lower():gsub("[%s%p]", "")
                    local cleanGlossary = glossary:lower():gsub("[%s%p]", "")
                    if #cleanText > 5 and cleanGlossary:find(cleanText, 1, true) then
                        print(string.format("  → DETECTED PROMPT REFLECTION: Transcription '%s' is likely a hallucination of the glossary.", text))
                        text = "" 
                        isHallucination = true
                    end
                end

                -- PRO-Level: Confidence Filtering (requires verbose_json - OpenAI only)
                -- Determine if we used verbose_json based on the response format
                if not isHallucination and response.segments then
                    local segments = response.segments
                    local filteredText = ""
                    local filteredCount = 0
                    
                    for _, segment in ipairs(segments) do
                        local noSpeechProb = segment.no_speech_prob or 0
                        local avgLogProb = segment.avg_logprob or 0
                        
                        -- Thresholds tuned for Whisper V3 Large/Turbo:
                        -- 1. no_speech_prob > 0.6: Very likely just background noise/silence
                        -- 2. avg_logprob < -1.0: Model is very uncertain about the text
                        if noSpeechProb < 0.6 and avgLogProb > -1.0 then
                            filteredText = filteredText .. segment.text
                        else
                            filteredCount = filteredCount + 1
                            print(string.format("  → Filtering hallucination: '%s' (p_no_speech: %.2f, logprob: %.2f)", 
                                segment.text:gsub("[\n\r]", " "):sub(1, 40), noSpeechProb, avgLogProb))
                        end
                    end
                    
                    if filteredCount > 0 then
                        print(string.format("  → Successfully removed %d hallucination segment(s)", filteredCount))
                        text = filteredText
                    end
                end

                -- Trim leading/trailing whitespace from transcription
                text = text:gsub("^%s+", ""):gsub("%s+$", "")
                print("Transcription successful. Text length: " .. #text)
                -- Log detailed info about response length for debugging truncation issues
                if #text < 100 then
                    print("  → Text is short (" .. #text .. " chars)")
                elseif #text > 1300 and #text < 1600 then
                    print("  → Text is in 1300-1600 range (" .. #text .. " chars) - TRUNCATION CHECK ENABLED")
                end
                if callback then callback(text, nil) end
            -- Check for successful transcription (Cloudflare format)
            elseif response and response.success == true and response.result and response.result.text then
                -- Trim leading/trailing whitespace from transcription
                local text = response.result.text:gsub("^%s+", ""):gsub("%s+$", "")
                print("Transcription successful (Cloudflare). Text length: " .. #text)
                -- Log detailed info about response length for debugging truncation issues
                if #text < 100 then
                    print("  → Text is short (" .. #text .. " chars)")
                elseif #text > 1300 and #text < 1600 then
                    print("  → Text is in 1300-1600 range (" .. #text .. " chars) - TRUNCATION CHECK ENABLED")
                end
                if callback then callback(text, nil) end
            elseif response and response.error then
                -- OpenAI/DeepInfra error format
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
            elseif response and response.success == false and response.errors then
                -- Cloudflare error format
                local errorMsg = "Unknown Cloudflare error"
                if response.errors[1] and response.errors[1].message then
                    errorMsg = response.errors[1].message
                    local errorCode = response.errors[1].code or "unknown"
                    print(string.format("ERROR: Cloudflare API error [%s]: %s", tostring(errorCode), errorMsg))
                end
                
                if callback then callback(nil, "Cloudflare API Error: " .. errorMsg) end
            else
                print("ERROR: Unknown response format")
                print("Response: " .. hs.inspect(response))
                if callback then callback(nil, "Unknown response format") end
            end
        else
            -- Curl command failed
            print("ERROR: Curl command failed with exit code: " .. exitCode)
            print("Command was: " .. commandForLog)
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
        end) -- End of pcall
        
        -- Handle pcall errors
        if not success then
            -- Clean up temp file on error
            if tempFile then
                os.remove(tempFile)
            end
            print("ERROR: Critical error in API callback: " .. tostring(callbackError))
            -- Ensure callback is called with error to prevent app from hanging
            if callback then 
                pcall(callback, nil, "Internal error: " .. tostring(callbackError))
            end
        end
    end, args)
    
    -- Persist task object to prevent garbage collection blocking
    table.insert(M.activeTasks, task)
    task:start()
end

return M

