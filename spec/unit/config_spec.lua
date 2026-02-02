-- spec/unit/config_spec.lua
-- Unit tests for config module

describe("config module", function()
    local config
    local mock_hs
    
    before_each(function()
        -- Setup mock Hammerspoon environment
        mock_hs = require("spec.support.mock_hs")
        mock_hs.reset()
        mock_hs.setup()
        
        -- Reload config module to get fresh instance
        package.loaded["config"] = nil
        config = require("config")
    end)
    
    after_each(function()
        mock_hs.teardown()
    end)
    
    describe("API Key management", function()
        it("should return nil for unset API key", function()
            assert.is_nil(config.getApiKey())
        end)
        
        it("should store and retrieve API key", function()
            local testKey = "sk-test123456789012345678"
            config.setApiKey(testKey)
            assert.are.equal(testKey, config.getApiKey())
        end)
        
        it("should update existing API key", function()
            config.setApiKey("sk-oldkey123")
            config.setApiKey("sk-newkey456")
            assert.are.equal("sk-newkey456", config.getApiKey())
        end)

        it("should fallback to global API key for transcription when dedicated is not set", function()
            local testKey = "sk-global-key"
            config.setApiKey(testKey)
            assert.are.equal(testKey, config.getTranscriptionApiKey())
        end)

        it("should use dedicated transcription API key when set", function()
            config.setApiKey("sk-global")
            config.setTranscriptionApiKey("sk-whisper-dedicated")
            assert.are.equal("sk-whisper-dedicated", config.getTranscriptionApiKey())
        end)

        it("should fallback to transcription API key for correction when dedicated is not set", function()
            config.setApiKey("sk-global")
            config.setTranscriptionApiKey("sk-transcription")
            assert.are.equal("sk-transcription", config.getCorrectionApiKey())
        end)

        it("should use dedicated correction API key when set", function()
            config.setApiKey("sk-global")
            config.setTranscriptionApiKey("sk-transcription")
            config.setCorrectionApiKey("sk-correction-dedicated")
            assert.are.equal("sk-correction-dedicated", config.getCorrectionApiKey())
        end)
    end)
    
    describe("Hotkey configuration", function()
        it("should return default hotkey when not set", function()
            local mods, key = config.getHotkey()
            assert.are.same({"cmd", "alt"}, mods)
            assert.are.equal("D", key)
        end)
        
        it("should store and retrieve custom hotkey", function()
            config.setHotkey({"ctrl", "shift"}, "R")
            local mods, key = config.getHotkey()
            assert.are.same({"ctrl", "shift"}, mods)
            assert.are.equal("R", key)
        end)
    end)
    
    describe("Language configuration", function()
        it("should return default language", function()
            assert.are.equal("auto", config.getLanguage())
        end)
        
        it("should store and retrieve language", function()
            config.setLanguage("de")
            assert.are.equal("de", config.getLanguage())
        end)
        
        it("should handle language code changes", function()
            config.setLanguage("en")
            assert.are.equal("en", config.getLanguage())
            config.setLanguage("fr")
            assert.are.equal("fr", config.getLanguage())
        end)
    end)
    
    describe("Boolean flags", function()
        describe("useFnKey", function()
            it("should return default value (true)", function()
                assert.is_true(config.getUseFnKey())
            end)
            
            it("should toggle on and off", function()
                config.setUseFnKey(false)
                assert.is_false(config.getUseFnKey())
                config.setUseFnKey(true)
                assert.is_true(config.getUseFnKey())
            end)
        end)
        
        describe("autoPaste", function()
            it("should return default value (true)", function()
                assert.is_true(config.getAutoPaste())
            end)
            
            it("should toggle on and off", function()
                config.setAutoPaste(false)
                assert.is_false(config.getAutoPaste())
                config.setAutoPaste(true)
                assert.is_true(config.getAutoPaste())
            end)
        end)
        
        describe("correctionEnabled", function()
            it("should return default value (false)", function()
                assert.is_false(config.getCorrectionEnabled())
            end)
            
            it("should enable and disable", function()
                config.setCorrectionEnabled(true)
                assert.is_true(config.getCorrectionEnabled())
                config.setCorrectionEnabled(false)
                assert.is_false(config.getCorrectionEnabled())
            end)
        end)
    end)
    
    describe("Base URL configuration", function()
        it("should return default transcription URL", function()
            assert.are.equal("https://api.openai.com/v1", config.getTranscriptionApiBaseUrl())
        end)

        it("should fallback to transcription URL for correction by default", function()
            config.setTranscriptionApiBaseUrl("https://api.custom.com/v1")
            assert.are.equal("https://api.custom.com/v1", config.getCorrectionApiBaseUrl())
        end)

        it("should return dedicated correction URL when set", function()
            config.setTranscriptionApiBaseUrl("https://api.transcribe.com/v1")
            config.setCorrectionApiBaseUrl("https://api.correct.com/v1")
            assert.are.equal("https://api.correct.com/v1", config.getCorrectionApiBaseUrl())
        end)
    end)

    describe("Rate limiting configuration", function()
        it("should return default max requests", function()
            assert.are.equal(10, config.getRateLimitMaxRequests())
        end)
        
        it("should return default window", function()
            assert.are.equal(60, config.getRateLimitWindow())
        end)
        
        it("should store and retrieve custom rate limits", function()
            config.setRateLimitMaxRequests(5)
            config.setRateLimitWindow(120)
            assert.are.equal(5, config.getRateLimitMaxRequests())
            assert.are.equal(120, config.getRateLimitWindow())
        end)
    end)
    
    describe("AI Correction configuration", function()
        it("should return default correction model", function()
            assert.are.equal("gpt-4o-mini", config.getCorrectionModel())
        end)
        
        it("should sanitize and store valid model names", function()
            assert.is_true(config.setCorrectionModel("gpt-4o"))
            assert.are.equal("gpt-4o", config.getCorrectionModel())
        end)
        
        it("should reject invalid model names", function()
            assert.is_false(config.setCorrectionModel("invalid model!@#"))
            -- Should keep previous valid value
            assert.are.equal("gpt-4o-mini", config.getCorrectionModel())
        end)
        
        it("should trim whitespace from model names", function()
            config.setCorrectionModel("  gpt-4o  ")
            assert.are.equal("gpt-4o", config.getCorrectionModel())
        end)
        
        it("should reject empty model names", function()
            assert.is_false(config.setCorrectionModel(""))
            assert.are.equal("gpt-4o-mini", config.getCorrectionModel())
        end)
        
        it("should return default system prompt", function()
            local prompt = config.getCorrectionSystemPrompt()
            assert.is_string(prompt)
            assert.is_true(#prompt > 0)
        end)
        
        it("should store and retrieve custom prompts", function()
            local customPrompt = "Fix grammar and spelling only."
            config.setCorrectionSystemPrompt(customPrompt)
            assert.are.equal(customPrompt, config.getCorrectionSystemPrompt())
        end)
        
        it("should reset to default on empty prompt", function()
            local original = config.getCorrectionSystemPrompt()
            assert.is_true(config.setCorrectionSystemPrompt(""))
            assert.are.equal(original, config.getCorrectionSystemPrompt())
        end)
        
        it("should trim prompts", function()
            config.setCorrectionSystemPrompt("  Test prompt  ")
            assert.are.equal("Test prompt", config.getCorrectionSystemPrompt())
        end)
    end)
    
    describe("Glossary management", function()
        it("should return empty string by default", function()
            assert.are.equal("", config.getGlossary())
        end)
        
        it("should store and retrieve glossary", function()
            local glossary = "Hammerspoon, macOS, OpenAI, Whisper"
            config.setGlossary(glossary)
            assert.are.equal(glossary, config.getGlossary())
        end)
        
        it("should trim glossary whitespace", function()
            config.setGlossary("  test, words  ")
            assert.are.equal("test, words", config.getGlossary())
        end)
        
        it("should truncate very long glossaries", function()
            local longGlossary = string.rep("word, ", 500)  -- >2000 chars
            config.setGlossary(longGlossary)
            local stored = config.getGlossary()
            assert.is_true(#stored <= 2000)
        end)
        
        it("should handle empty glossary", function()
            config.setGlossary("")
            assert.are.equal("", config.getGlossary())
        end)
    end)
    
    describe("Constants", function()
        it("should have correct bundle ID", function()
            assert.are.equal("com.simon.dictator", config.BUNDLE_ID)
        end)
        
        it("should have all required keys defined", function()
            assert.is_string(config.API_KEY_KEY)
            assert.is_string(config.HOTKEY_MODS_KEY)
            assert.is_string(config.LANGUAGE_KEY)
            assert.is_string(config.CORRECTION_MODEL_KEY)
        end)
    end)
end)
