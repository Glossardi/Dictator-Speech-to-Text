-- api_client.lua
-- Low-level HTTP/Task handling for API requests
-- Kapselt hs.task, Retry-Logik und Anbieter-spezifische Payload-Formatierung.

local M = {}
local config = require("config")
local utils = require("utils")

M.MAX_RETRIES = 3
M.INITIAL_RETRY_DELAY = 1
M.MAX_RETRY_DELAY = 60
M.activeTasks = {}

-- Utility: Calculate retry delay with exponential backoff and jitter
function M.calculateRetryDelay(attemptNumber, retryAfter)
    if retryAfter and tonumber(retryAfter) then
        return math.min(tonumber(retryAfter), M.MAX_RETRY_DELAY)
    end
    local delay = M.INITIAL_RETRY_DELAY * (2 ^ attemptNumber)
    return math.min(delay + math.random(), M.MAX_RETRY_DELAY)
end

-- Utility: Convert audio file to base64 for Cloudflare
function M.audioFileToBase64(filePath)
    local file = io.open(filePath, "rb")
    if not file then return nil, "Cannot open audio file" end
    local content = file:read("*all")
    file:close()
    if not content or #content == 0 then return nil, "Empty audio file" end
    
    -- Use Hammerspoon's built-in base64 encoding instead of external openssl
    return hs.base64.encode(content), nil
end

-- Validation helpers
function M.validateApiKey(apiKey)
    if not apiKey or apiKey == "" then
        return false, "API key is empty"
    end
    if #apiKey < 20 then
        return false, "API key too short (minimum 20 characters)"
    end
    return true
end

function M.validateAudioFile(filePath)
    if not filePath or filePath == "" then return false, "No file path provided" end
    if not utils.file_exists(filePath) then return false, "Audio file does not exist" end
    local fileSize = utils.get_file_size(filePath)
    if not fileSize then return false, "Cannot determine file size" end
    
    local maxSize = 25 * 1024 * 1024  -- 25MB in bytes
    if fileSize > maxSize then
        return false, string.format("File too large (%.2f MB, max 25 MB)", fileSize / (1024 * 1024))
    end
    return true
end

-- Parse rate limit headers from curl response
function M.parseRateLimitHeaders(curlOutput)
    local headers = {}
    for line in curlOutput:gmatch("[^\r\n]+") do
        local key, value = line:match("^x%-ratelimit%-([^:]+):%s*(.+)$")
        if key and value then
            headers[key] = value
        end
    end
    return headers
end

-- Generic hs.task wrapper with retry and cleanup
function M.performRequest(name, url, args, attempt, tempFile, onResult)
    local requestStart = hs.timer.secondsSinceEpoch()
    local task = hs.task.new("/usr/bin/curl", function(exitCode, stdOut, stdErr)
        if tempFile then os.remove(tempFile) end
        for i, t in ipairs(M.activeTasks) do
            if t == task then table.remove(M.activeTasks, i); break end
        end

        local elapsed = hs.timer.secondsSinceEpoch() - requestStart
        if exitCode == 0 then
            local statusMatch = stdOut:match("\nHTTP_STATUS:(%d+)%s*$")
            local statusCode = statusMatch and tonumber(statusMatch) or nil
            local body = stdOut:gsub("\nHTTP_STATUS:%d+%s*$", "")
            onResult(true, statusCode, body, elapsed)
        else
            onResult(false, nil, stdErr, elapsed)
        end
    end, args)

    table.insert(M.activeTasks, task)
    task:start()
end

return M
