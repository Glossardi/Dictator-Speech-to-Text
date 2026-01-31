-- spec/unit/rate_limiter_spec.lua
-- Unit tests for rate_limiter module

describe("rate_limiter module", function()
    local rate_limiter
    local config
    local mock_hs
    local original_os_time
    local mock_time
    
    before_each(function()
        -- Setup mock Hammerspoon environment
        mock_hs = require("spec.support.mock_hs")
        mock_hs.reset()
        mock_hs.setup()
        
        -- Mock os.time for deterministic testing
        mock_time = 1000
        original_os_time = os.time
        os.time = function() return mock_time end
        
        -- Reload modules
        package.loaded["config"] = nil
        package.loaded["rate_limiter"] = nil
        config = require("config")
        rate_limiter = require("rate_limiter")
    end)
    
    after_each(function()
        -- Restore original os.time
        os.time = original_os_time
        mock_hs.teardown()
    end)
    
    describe("initialization", function()
        it("should initialize with default configuration", function()
            rate_limiter.init()
            assert.are.equal(10, rate_limiter.maxTokens)
            assert.are.equal(10, rate_limiter.tokens)
            assert.is_true(math.abs(rate_limiter.refillRate - (10/60)) < 0.001)
        end)
        
        it("should initialize with custom configuration", function()
            config.setRateLimitMaxRequests(5)
            config.setRateLimitWindow(120)
            rate_limiter.init()
            
            assert.are.equal(5, rate_limiter.maxTokens)
            assert.are.equal(5, rate_limiter.tokens)
            assert.is_true(math.abs(rate_limiter.refillRate - (5/120)) < 0.001)
        end)
        
        it("should set lastRefill to current time", function()
            rate_limiter.init()
            assert.are.equal(mock_time, rate_limiter.lastRefill)
        end)
    end)
    
    describe("token refilling", function()
        before_each(function()
            rate_limiter.init()
            -- Start with full bucket (10 tokens)
            assert.are.equal(10, rate_limiter.tokens)
        end)
        
        it("should not refill if no time has passed", function()
            rate_limiter.tokens = 2
            rate_limiter.refillTokens()
            assert.are.equal(2, rate_limiter.tokens)
        end)
        
        it("should refill tokens over time", function()
            rate_limiter.tokens = 0
            mock_time = mock_time + 6  -- 6 seconds later
            rate_limiter.refillTokens()
            
            -- 6 seconds * (10/60) tokens/sec = 1 token
            assert.is_true(math.abs(rate_limiter.tokens - 1) < 0.001)
        end)
        
        it("should not exceed max tokens", function()
            rate_limiter.tokens = 2
            mock_time = mock_time + 100  -- 100 seconds later (would add >10 tokens)
            rate_limiter.refillTokens()
            
            assert.are.equal(10, rate_limiter.tokens)  -- Capped at maxTokens
        end)
        
        it("should update lastRefill time", function()
            local initialTime = rate_limiter.lastRefill
            mock_time = mock_time + 10
            rate_limiter.refillTokens()
            
            assert.are.equal(mock_time, rate_limiter.lastRefill)
            assert.are_not.equal(initialTime, rate_limiter.lastRefill)
        end)
    end)
    
    describe("canMakeRequest", function()
        before_each(function()
            rate_limiter.init()
        end)
        
        it("should return true when tokens are available", function()
            assert.is_true(rate_limiter.canMakeRequest())
        end)
        
        it("should return false when no tokens available", function()
            rate_limiter.tokens = 0.5  -- Less than 1
            assert.is_false(rate_limiter.canMakeRequest())
        end)
        
        it("should auto-initialize if not initialized", function()
            rate_limiter.tokens = nil
            assert.is_true(rate_limiter.canMakeRequest())
            assert.is_not_nil(rate_limiter.tokens)
        end)
        
        it("should account for time passing", function()
            rate_limiter.tokens = 0
            assert.is_false(rate_limiter.canMakeRequest())
            
            mock_time = mock_time + 6  -- Add 1 token
            assert.is_true(rate_limiter.canMakeRequest())
        end)
    end)
    
    describe("consumeToken", function()
        before_each(function()
            rate_limiter.init()
        end)
        
        it("should consume token when available", function()
            local allowed, waitTime = rate_limiter.consumeToken()
            assert.is_true(allowed)
            assert.are.equal(0, waitTime)
            assert.are.equal(9, rate_limiter.tokens)
        end)
        
        it("should allow multiple requests within limit", function()
            -- Consume all tokens
            for i=1, 10 do
                local allowed, _ = rate_limiter.consumeToken()
                assert.is_true(allowed, "Request " .. i .. " should be allowed")
            end
            
            assert.are.equal(0, rate_limiter.tokens)
            
            local allowed_extra, _ = rate_limiter.consumeToken()
            assert.is_false(allowed_extra)
        end)
        
        it("should reject request when rate limited", function()
            -- Consume all tokens
            rate_limiter.tokens = 0
            
            local allowed, waitTime = rate_limiter.consumeToken()
            assert.is_false(allowed)
            assert.is_true(waitTime > 0)
        end)
        
        it("should calculate correct wait time", function()
            rate_limiter.tokens = 0
            local allowed, waitTime = rate_limiter.consumeToken()
            
            assert.is_false(allowed)
            -- 1 token needed / (10/60) tokens per second = 6 seconds
            assert.are.equal(6, waitTime)
        end)
        
        it("should allow request after refill period", function()
            -- Consume all tokens
            rate_limiter.tokens = 0
            local allowed1, _ = rate_limiter.consumeToken()
            assert.is_false(allowed1)
            
            -- Wait for refill (6 seconds = 1 token)
            mock_time = mock_time + 6
            local allowed2, _ = rate_limiter.consumeToken()
            assert.is_true(allowed2)
        end)
    end)
    
    describe("getStatus", function()
        before_each(function()
            rate_limiter.init()
        end)
        
        it("should return current status", function()
            local status = rate_limiter.getStatus()
            
            assert.is_table(status)
            assert.are.equal(10, status.tokens)
            assert.are.equal(10, status.maxTokens)
            assert.is_true(math.abs(status.refillRate - (10/60)) < 0.001)
            assert.are.equal(100, status.percentAvailable)
        end)
        
        it("should reflect consumed tokens", function()
            rate_limiter.consumeToken()
            local status = rate_limiter.getStatus()
            
            assert.are.equal(9, status.tokens)
            assert.are.equal(90, status.percentAvailable)
        end)
        
        it("should auto-initialize if needed", function()
            rate_limiter.tokens = nil
            local status = rate_limiter.getStatus()
            assert.is_not_nil(status.tokens)
        end)
    end)
    
    describe("reset", function()
        it("should reset to full capacity", function()
            rate_limiter.init()
            rate_limiter.tokens = 1
            
            assert.are.equal(1, rate_limiter.tokens)
            
            rate_limiter.reset()
            assert.are.equal(10, rate_limiter.tokens)
        end)
        
        it("should reset lastRefill time", function()
            rate_limiter.init()
            mock_time = mock_time + 100
            rate_limiter.reset()
            
            assert.are.equal(mock_time, rate_limiter.lastRefill)
        end)
    end)
    
    describe("token bucket algorithm", function()
        it("should handle fractional tokens correctly", function()
            config.setRateLimitMaxRequests(10)
            config.setRateLimitWindow(3)  -- 3.33 tokens per second
            rate_limiter.init()
            
            rate_limiter.tokens = 0.8  -- Fractional tokens
            mock_time = mock_time + 1
            rate_limiter.refillTokens()
            
            -- Should have ~4.13 tokens now
            assert.is_true(rate_limiter.tokens > 1)
        end)
        
        it("should handle burst requests followed by refill", function()
            rate_limiter.init()
            
            -- Burst: consume all tokens
            rate_limiter.tokens = 0
            assert.are.equal(0, rate_limiter.tokens)
            
            -- Wait half the window (30s = 5 tokens)
            mock_time = mock_time + 30
            assert.is_true(rate_limiter.canMakeRequest())
            
            -- Can make one request
            local allowed, _ = rate_limiter.consumeToken()
            assert.is_true(allowed)
            
            -- And more
            assert.are.equal(4, rate_limiter.tokens)
        end)
    end)
end)
