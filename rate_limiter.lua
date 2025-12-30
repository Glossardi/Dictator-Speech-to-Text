--[[
Rate Limiter Module - Token Bucket Algorithm
Prevents exceeding API rate limits by enforcing a maximum request rate.

Default: 3 requests per minute (based on OpenAI Whisper API community reports)
Configurable via settings for flexibility.
--]]

local M = {}
local config = require("config")

-- Rate limiter state (global to persist across calls)
M.tokens = nil  -- Current number of available tokens
M.lastRefill = nil  -- Last time tokens were refilled
M.maxTokens = nil  -- Maximum tokens (bucket capacity)
M.refillRate = nil  -- Tokens added per second

-- Initialize rate limiter with configuration
function M.init()
    M.maxTokens = config.getRateLimitMaxRequests() or 3  -- Default: 3 requests
    local window = config.getRateLimitWindow() or 60  -- Default: 60 seconds
    M.refillRate = M.maxTokens / window  -- Tokens per second
    M.tokens = M.maxTokens  -- Start with full bucket
    M.lastRefill = os.time()
    
    print(string.format("Rate limiter initialized: %d requests per %d seconds", M.maxTokens, window))
end

-- Refill tokens based on elapsed time
function M.refillTokens()
    local now = os.time()
    local elapsed = now - M.lastRefill
    
    if elapsed > 0 then
        local newTokens = elapsed * M.refillRate
        M.tokens = math.min(M.maxTokens, M.tokens + newTokens)
        M.lastRefill = now
    end
end

-- Check if a request can be made (without consuming a token)
function M.canMakeRequest()
    if not M.tokens then M.init() end
    
    M.refillTokens()
    return M.tokens >= 1
end

-- Attempt to consume a token for a request
-- Returns: true if allowed, false if rate limited
-- Also returns wait time in seconds if rate limited
function M.consumeToken()
    if not M.tokens then M.init() end
    
    M.refillTokens()
    
    if M.tokens >= 1 then
        M.tokens = M.tokens - 1
        print(string.format("Rate limiter: Token consumed. Remaining: %.2f", M.tokens))
        return true, 0
    else
        -- Calculate wait time until next token is available
        local tokensNeeded = 1 - M.tokens
        local waitTime = math.ceil(tokensNeeded / M.refillRate)
        print(string.format("Rate limiter: Rate limit exceeded. Wait %d seconds.", waitTime))
        return false, waitTime
    end
end

-- Get current status for debugging/display
function M.getStatus()
    if not M.tokens then M.init() end
    M.refillTokens()
    
    return {
        tokens = M.tokens,
        maxTokens = M.maxTokens,
        refillRate = M.refillRate,
        percentAvailable = (M.tokens / M.maxTokens) * 100
    }
end

-- Reset rate limiter (useful for testing or config changes)
function M.reset()
    M.init()
end

return M
