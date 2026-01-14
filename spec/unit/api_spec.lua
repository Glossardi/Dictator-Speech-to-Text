-- spec/unit/api_spec.lua
-- Unit tests for api module (validation and retry logic)

describe("api module", function()
    local api
    local config
    local utils
    local mock_hs
    
    before_each(function()
        -- Setup mock Hammerspoon environment
        mock_hs = require("spec.support.mock_hs")
        mock_hs.reset()
        mock_hs.setup()
        
        -- Reload modules
        package.loaded["config"] = nil
        package.loaded["utils"] = nil
        package.loaded["api"] = nil
        config = require("config")
        utils = require("utils")
        api = require("api")
    end)
    
    after_each(function()
        mock_hs.teardown()
    end)
    
    describe("validateApiKey", function()
        it("should accept valid OpenAI API keys", function()
            local valid, err = api.validateApiKey("sk-1234567890123456789012345678901234567890")
            assert.is_true(valid)
            assert.is_nil(err)
        end)
        
        it("should reject empty API key", function()
            local valid, err = api.validateApiKey("")
            assert.is_false(valid)
            assert.are.equal("API key is empty", err)
        end)
        
        it("should reject nil API key", function()
            local valid, err = api.validateApiKey(nil)
            assert.is_false(valid)
            assert.are.equal("API key is empty", err)
        end)
        
        it("should reject API key without 'sk-' prefix", function()
            local valid, err = api.validateApiKey("invalid-key-format")
            assert.is_false(valid)
            assert.is_true(err:match("should start with 'sk%-'") ~= nil)
        end)
        
        it("should reject API key that is too short", function()
            local valid, err = api.validateApiKey("sk-short")
            assert.is_false(valid)
            assert.are.equal("API key too short", err)
        end)
        
        it("should accept minimum length valid key", function()
            local valid, err = api.validateApiKey("sk-12345678901234567890")
            assert.is_true(valid)
            assert.is_nil(err)
        end)
    end)
    
    describe("validateAudioFile", function()
        it("should reject empty file path", function()
            local valid, err = api.validateAudioFile("")
            assert.is_false(valid)
            assert.are.equal("No file path provided", err)
        end)
        
        it("should reject nil file path", function()
            local valid, err = api.validateAudioFile(nil)
            assert.is_false(valid)
            assert.are.equal("No file path provided", err)
        end)
        
        it("should reject non-existent file", function()
            local valid, err = api.validateAudioFile("/nonexistent/file.flac")
            assert.is_false(valid)
            assert.are.equal("Audio file does not exist", err)
        end)
        
        it("should accept valid file with mock", function()
            -- Create a temporary file
            local tempFile = os.tmpname()
            local f = io.open(tempFile, "w")
            f:write("test audio data")
            f:close()
            
            local valid, err = api.validateAudioFile(tempFile)
            assert.is_true(valid)
            assert.is_nil(err)
            
            os.remove(tempFile)
        end)
        
        it("should reject files larger than 25MB", function()
            -- Create a temp file
            local tempFile = os.tmpname()
            local f = io.open(tempFile, "w")
            f:write("test")
            f:close()
            
            -- Mock file size to be over 25MB
            local original_get_file_size = utils.get_file_size
            utils.get_file_size = function(path)
                return 26 * 1024 * 1024  -- 26MB
            end
            
            local valid, err = api.validateAudioFile(tempFile)
            assert.is_false(valid)
            assert.is_true(err:match("File too large") ~= nil)
            assert.is_true(err:match("26%.00 MB") ~= nil)
            
            -- Restore and cleanup
            utils.get_file_size = original_get_file_size
            os.remove(tempFile)
        end)
        
        it("should accept files at the 25MB limit", function()
            local tempFile = os.tmpname()
            local f = io.open(tempFile, "w")
            f:write("test")
            f:close()
            
            -- Mock exact size limit
            local original_get_file_size = utils.get_file_size
            utils.get_file_size = function(path)
                return 25 * 1024 * 1024  -- Exactly 25MB
            end
            
            local valid, err = api.validateAudioFile(tempFile)
            assert.is_true(valid)
            assert.is_nil(err)
            
            utils.get_file_size = original_get_file_size
            os.remove(tempFile)
        end)
    end)
    
    describe("calculateRetryDelay", function()
        it("should use retryAfter header if provided", function()
            local delay = api.calculateRetryDelay(0, "5")
            assert.are.equal(5, delay)
        end)
        
        it("should cap retryAfter at MAX_RETRY_DELAY", function()
            local delay = api.calculateRetryDelay(0, "120")
            assert.are.equal(60, delay)  -- MAX_RETRY_DELAY is 60
        end)
        
        it("should use exponential backoff when no retryAfter", function()
            -- First retry: 1 * (2^0) = 1 second + jitter
            local delay0 = api.calculateRetryDelay(0, nil)
            assert.is_true(delay0 >= 1 and delay0 <= 3)
            
            -- Second retry: 1 * (2^1) = 2 seconds + jitter
            local delay1 = api.calculateRetryDelay(1, nil)
            assert.is_true(delay1 >= 2 and delay1 <= 4)
            
            -- Third retry: 1 * (2^2) = 4 seconds + jitter
            local delay2 = api.calculateRetryDelay(2, nil)
            assert.is_true(delay2 >= 4 and delay2 <= 6)
        end)
        
        it("should cap exponential backoff at MAX_RETRY_DELAY", function()
            -- Large attempt number would overflow, should cap at 60
            local delay = api.calculateRetryDelay(10, nil)
            assert.are.equal(60, delay)
        end)
        
        it("should add random jitter", function()
            -- Run multiple times and check variation
            local delays = {}
            for i = 1, 5 do
                delays[i] = api.calculateRetryDelay(0, nil)
            end
            
            -- Check that not all delays are identical (jitter is working)
            local allSame = true
            for i = 2, #delays do
                if delays[i] ~= delays[1] then
                    allSame = false
                    break
                end
            end
            assert.is_false(allSame)
        end)
    end)
    
    describe("parseRateLimitHeaders", function()
        it("should parse rate limit headers from curl output", function()
            local curlOutput = [[
HTTP/2 200
content-type: application/json
x-ratelimit-limit-requests: 50
x-ratelimit-remaining-requests: 49
x-ratelimit-reset-requests: 1.2s
]]
            local headers = api.parseRateLimitHeaders(curlOutput)
            assert.are.equal("50", headers["limit-requests"])
            assert.are.equal("49", headers["remaining-requests"])
            assert.are.equal("1.2s", headers["reset-requests"])
        end)
        
        it("should return empty table for output without headers", function()
            local curlOutput = "No headers here"
            local headers = api.parseRateLimitHeaders(curlOutput)
            assert.are.same({}, headers)
        end)
        
        it("should handle multiple header formats", function()
            local curlOutput = [[
x-ratelimit-limit: 100
x-ratelimit-remaining: 99
x-ratelimit-reset: 60
]]
            local headers = api.parseRateLimitHeaders(curlOutput)
            assert.are.equal("100", headers["limit"])
            assert.are.equal("99", headers["remaining"])
            assert.are.equal("60", headers["reset"])
        end)
    end)
    
    describe("transcribe validation", function()
        it("should reject transcription without valid API key", function()
            local callbackCalled = false
            local errorReceived = nil
            
            api.transcribe("/fake/file.flac", function(result, err)
                callbackCalled = true
                errorReceived = err
            end)
            
            assert.is_true(callbackCalled)
            assert.is_not_nil(errorReceived)
            assert.is_true(errorReceived:match("API key") ~= nil)
        end)
        
        it("should reject transcription with invalid audio file", function()
            config.setApiKey("sk-12345678901234567890")
            
            local callbackCalled = false
            local errorReceived = nil
            
            api.transcribe("/nonexistent/file.flac", function(result, err)
                callbackCalled = true
                errorReceived = err
            end)
            
            assert.is_true(callbackCalled)
            assert.is_not_nil(errorReceived)
            assert.is_true(errorReceived:match("does not exist") ~= nil)
        end)
    end)
    
    describe("correctText validation", function()
        it("should reject correction without valid API key", function()
            local callbackCalled = false
            local errorReceived = nil
            
            api.correctText("Some text", function(result, err)
                callbackCalled = true
                errorReceived = err
            end)
            
            assert.is_true(callbackCalled)
            assert.is_not_nil(errorReceived)
            assert.is_true(errorReceived:match("API key") ~= nil)
        end)
        
        it("should reject empty text", function()
            config.setApiKey("sk-12345678901234567890")
            
            local callbackCalled = false
            local errorReceived = nil
            
            api.correctText("", function(result, err)
                callbackCalled = true
                errorReceived = err
            end)
            
            assert.is_true(callbackCalled)
            assert.are.equal("No text to correct", errorReceived)
        end)
        
        it("should reject nil text", function()
            config.setApiKey("sk-12345678901234567890")
            
            local callbackCalled = false
            local errorReceived = nil
            
            api.correctText(nil, function(result, err)
                callbackCalled = true
                errorReceived = err
            end)
            
            assert.is_true(callbackCalled)
            assert.are.equal("No text to correct", errorReceived)
        end)
    end)
    
    describe("module constants", function()
        it("should have correct retry configuration", function()
            assert.are.equal(3, api.MAX_RETRIES)
            assert.are.equal(1, api.INITIAL_RETRY_DELAY)
            assert.are.equal(60, api.MAX_RETRY_DELAY)
        end)
        
        it("should initialize activeTasks table", function()
            assert.is_table(api.activeTasks)
        end)
    end)
end)
