-- api.lua
-- High-level API orchestration for Dictator
-- Coordinates transcription and correction using client and filter modules.

local M = {}
local config = require("config")
local utils = require("utils")
local client = require("api_client")
local filters = require("api_filters")

-- Re-export constants and internal methods for backward compatibility (and tests)
M.MAX_RETRIES = client.MAX_RETRIES
M.INITIAL_RETRY_DELAY = client.INITIAL_RETRY_DELAY
M.MAX_RETRY_DELAY = client.MAX_RETRY_DELAY
M.activeTasks = client.activeTasks
M.validateApiKey = client.validateApiKey
M.validateAudioFile = client.validateAudioFile
M.calculateRetryDelay = client.calculateRetryDelay
M.parseRateLimitHeaders = client.parseRateLimitHeaders

-- Provider detection
function M.isCloudflareProvider(baseUrl)
    if not baseUrl then return false end
    return baseUrl:lower():find("cloudflare.com", 1, true) ~= nil
end

-- Transcribe audio file to text
function M.transcribe(audioFilePath, callback)
    local apiKey = config.getTranscriptionApiKey()
    
    local ok, err = client.validateApiKey(apiKey)
    if not ok then if callback then callback(nil, err) end; return end
    
    ok, err = client.validateAudioFile(audioFilePath)
    if not ok then if callback then callback(nil, err) end; return end

    M.transcribeWithRetry(audioFilePath, apiKey, 0, callback)
end

function M.transcribeWithRetry(audioFilePath, apiKey, attempt, callback)
    if attempt >= client.MAX_RETRIES then
        if callback then callback(nil, "Max transcription retries exceeded") end
        return
    end

    local baseUrl = config.getTranscriptionApiBaseUrl()
    local model = config.getTranscriptionModel()
    local language = config.getLanguage()
    local glossary = config.getGlossary()
    local isCloudflare = M.isCloudflareProvider(baseUrl)
    
    local url, args, tempFile
    
    if isCloudflare then
        url = baseUrl:gsub("/v1/openai$", "") .. "/ai/run/" .. model
        local base64, err = client.audioFileToBase64(audioFilePath)
        if not base64 then if callback then callback(nil, err) end; return end
        
        local payload = { audio = base64, temperature = 0 }
        if language and language ~= "auto" then payload.language = language end
        if glossary and glossary ~= "" then payload.initial_prompt = glossary:sub(1, 1000) end
        
        tempFile = os.tmpname()
        local f = io.open(tempFile, "w")
        f:write(hs.json.encode(payload))
        f:close()
        
        args = { "-s", "-w", "\nHTTP_STATUS:%{http_code}", "--compressed", "--connect-timeout", "10", "--max-time", "120",
                 url, "-H", "Authorization: Bearer " .. apiKey, "-H", "Content-Type: application/json", "-d", "@" .. tempFile }
    else
        url = baseUrl .. "/audio/transcriptions"
        args = { "-s", "-w", "\nHTTP_STATUS:%{http_code}", "--compressed", "--connect-timeout", "10", "--max-time", "90",
                 url, "-H", "Authorization: Bearer " .. apiKey, "-F", "file=@" .. audioFilePath, "-F", "model=" .. model, "-F", "temperature=0" }
        
        if baseUrl:lower():find("api.openai.com", 1, true) then
            table.insert(args, "-F"); table.insert(args, "response_format=verbose_json")
        end
        if language and language ~= "auto" then
            table.insert(args, "-F"); table.insert(args, "language=" .. language)
        end
        if glossary and glossary ~= "" then
            table.insert(args, "-F"); table.insert(args, "prompt=" .. glossary:sub(1, 1000))
        end
    end

    client.performRequest("transcribe", url, args, attempt, tempFile, function(success, status, body, elapsed)
        if not success then
            local delay = client.calculateRetryDelay(attempt)
            print(string.format("Transcription network error, retrying in %.1fs...", delay))
            hs.timer.doAfter(delay, function() M.transcribeWithRetry(audioFilePath, apiKey, attempt + 1, callback) end)
            return
        end

        if status == 429 or (status >= 500 and status < 600) then
            local delay = client.calculateRetryDelay(attempt)
            print(string.format("Transcription API error (%d), retrying in %.1fs...", status, delay))
            hs.timer.doAfter(delay, function() M.transcribeWithRetry(audioFilePath, apiKey, attempt + 1, callback) end)
            return
        end

        local ok, resp = pcall(hs.json.decode, body)
        if not ok or not resp then if callback then callback(nil, "Invalid JSON") end; return end
        if resp.error or (resp.success == false and resp.errors) then
            local msg = (resp.error and resp.error.message) or (resp.errors and resp.errors[1] and resp.errors[1].message) or "API Error"
            if callback then callback(nil, msg) end; return
        end

        local text = resp.text or (resp.result and resp.result.text)
        if not text then if callback then callback(nil, "Unknown response format") end; return end

        -- Hallucination filtering
        if filters.isGlossaryHallucination(text, glossary) then
            text = ""
        elseif resp.segments then
            local filtered, count = filters.filterSegments(resp.segments)
            if count > 0 then text = filtered end
        end

        callback(text:gsub("^%s+", ""):gsub("%s+$", ""), nil)
    end)
end

-- AI text correction orchestration
function M.correctText(text, callback, contextXml)
    local apiKey = config.getCorrectionApiKey()
    local ok, err = client.validateApiKey(apiKey)
    if not ok then if callback then callback(nil, err) end; return end
    if not text or text == "" then if callback then callback(nil, "No text to correct") end; return end

    M.correctTextWithRetry(text, apiKey, 0, callback, true, contextXml)
end

function M.correctTextWithRetry(text, apiKey, attempt, callback, includeTemp, contextXml)
    if attempt >= client.MAX_RETRIES then
        if callback then callback(nil, "Max correction retries exceeded") end
        return
    end

    local baseUrl = config.getCorrectionApiBaseUrl()
    local isCloudflare = M.isCloudflareProvider(baseUrl)
    local url = isCloudflare and (baseUrl:gsub("/v1/openai$", "") .. "/v1/chat/completions") or (baseUrl .. "/chat/completions")
    
    local userContent = ""
    if contextXml and contextXml ~= "" then
        userContent = contextXml .. "\n\n"
    end

    local glossary = config.getGlossary()
    if glossary and glossary ~= "" then
        userContent = userContent .. "<glossary>" .. glossary .. "</glossary>\n\n"
    end

    userContent = userContent .. "<transcript>" .. text .. "</transcript>"

    local payload = {
        model = config.getCorrectionModel(),
        messages = {
            { role = "system", content = config.getCorrectionSystemPrompt() },
            { role = "user", content = userContent }
        },
        stop = {"\nInput:", "<|endoftext|>", "User:", "<transcript>"}
    }
    if includeTemp then
        payload.temperature = 0.0; payload.top_p = 1.0; payload.frequency_penalty = 0.0; payload.max_tokens = 2048
    end

    local args = { "-s", "-w", "\nHTTP_STATUS:%{http_code}", "--compressed", "--connect-timeout", "10", "--max-time", "20",
                   "-H", "Authorization: Bearer " .. apiKey, "-H", "Content-Type: application/json", "-d", hs.json.encode(payload), url }

    client.performRequest("correct", url, args, attempt, nil, function(success, status, body, elapsed)
        if not success or status == 429 or status >= 500 then
            local delay = client.calculateRetryDelay(attempt)
            hs.timer.doAfter(delay, function() M.correctTextWithRetry(text, apiKey, attempt + 1, callback, includeTemp, contextXml) end)
            return
        end

        local ok, resp = pcall(hs.json.decode, body)
        if not ok or not resp then if callback then callback(nil, "Invalid JSON") end; return end
        
        if resp.error and status == 400 and includeTemp and tostring(resp.error.message):lower():find("temperature") then
            M.correctTextWithRetry(text, apiKey, attempt, callback, false, contextXml)
            return
        end

        local content
        if resp.choices and resp.choices[1] and resp.choices[1].message then
            content = resp.choices[1].message.content
        elseif resp.result and (resp.result.response or type(resp.result) == "string") then
            content = resp.result.response or resp.result
        end

        if content then
            -- Clean common labels and code fences
            content = content:gsub("^%s+", ""):gsub("%s+$", "")
            
            -- 1. Remove typical AI preambles first
            local preambles = { 
                "^Output:%s*", "^Result:%s*", "^Here is the text:%s*", 
                "^Sure, here is the text:%s*", "^Corrected text:%s*",
                "^Output:%s*\n", "^Result:%s*\n", "^Here is the corrected text:%s*"
            }
            
            local changed = true
            while changed do
                changed = false
                for _, pattern in ipairs(preambles) do
                    local newContent = content:gsub(pattern, "")
                    if newContent ~= content then
                        content = newContent:gsub("^%s+", "") -- trim start after removal
                        changed = true
                    end
                end
            end
            
            -- 2. Remove code fences (```markdown ... ``` or ```text ... ``` or just ```)
            content = content:gsub("^```%w*%s*\n", ""):gsub("\n?```$", "")
            
            -- Final trim
            content = content:gsub("^%s+", ""):gsub("%s+$", "")
            
            callback(content, nil)
        else
            callback(nil, "Unknown correction response format")
        end
    end)
end

return M
