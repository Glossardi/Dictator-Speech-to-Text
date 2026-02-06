-- spec/unit/correction_refinement_spec.lua
-- Unit tests for AI correction refinements (cleanup, glossary, stop sequences)

describe("AI correction refinements", function()
    local api
    local config
    local mock_hs
    
    before_each(function()
        -- Setup mock Hammerspoon environment
        mock_hs = require("spec.support.mock_hs")
        mock_hs.reset()
        mock_hs.setup()
        
        -- Reload modules
        package.loaded["config"] = nil
        package.loaded["api"] = nil
        config = require("config")
        api = require("api")
        
        config.setApiKey("sk-12345678901234567890")
    end)
    
    after_each(function()
        mock_hs.teardown()
    end)
    
    describe("correctText context awareness", function()
        it("should include context XML in user message if provided", function()
            local context = "<context><app_name>TestApp</app_name></context>"
            api.correctText("Transcribed text", function() end, context)
            
            local lastCall = mock_hs.getLastCall("task_new")
            assert.is_not_nil(lastCall)
            
            local args = lastCall.args
            local jsonPayload = nil
            for i, arg in ipairs(args) do
                if arg == "-d" then
                    jsonPayload = args[i+1]
                    break
                end
            end
            
            assert.is_not_nil(jsonPayload)
            -- Use string matching instead of decoding for robustness
            assert.is_true(jsonPayload:find("<context>") ~= nil)
            assert.is_true(jsonPayload:find("TestApp") ~= nil)
            assert.is_true(jsonPayload:find("<transcript>Transcribed text</transcript>") ~= nil)
        end)
    end)
    
    describe("correctTextWithRetry refinements", function()
        it("should include stop sequences in payload", function()
            api.correctText("Test text", function() end)
            
            local lastCall = mock_hs.getLastCall("task_new")
            assert.is_not_nil(lastCall)
            
            local args = lastCall.args
            local jsonPayload = nil
            for i, arg in ipairs(args) do
                if arg == "-d" then
                    jsonPayload = args[i+1]
                    break
                end
            end
            
            assert.is_not_nil(jsonPayload)
            -- Use string matching instead of decoding for robustness if json mock is simple
            assert.is_true(jsonPayload:find('"stop":%[') ~= nil)
            assert.is_true(jsonPayload:find('"<transcript>"') ~= nil)
        end)
        
        it("should include glossary in user content if provided", function()
            config.setGlossary("MyTerm=MyFix")
            api.correctText("Test text", function() end)
            
            local lastCall = mock_hs.getLastCall("task_new")
            local args = lastCall.args
            local jsonPayload = nil
            for i, arg in ipairs(args) do
                if arg == "-d" then
                    jsonPayload = args[i+1]
                    break
                end
            end
            
            assert.is_true(jsonPayload:find("<glossary>MyTerm=MyFix</glossary>") ~= nil)
        end)
        
        it("should cleanup AI response preambles and code fences", function()
            local returnedText = nil
            
            -- Test with "Output:" preamble and code fences
            api.correctText("raw text", function(text)
                returnedText = text
            end)
            
            local lastCall = mock_hs.getLastCall("task_new")
            local task = lastCall.task
            
            local mockResponse = '{"choices":[{"message":{"content":"Output: ```text\\nCorrected text here\\n```"}}], "HTTP_STATUS:200":""}'
            -- The mock task setup expects the callback to be called with (exitCode, stdOut, stdErr)
            -- stdOut should match what curl returns with our custom formatting
            local stdOut = mockResponse .. "\nHTTP_STATUS:200"
            
            task._callback(0, stdOut, "")
            
            assert.are.equal("Corrected text here", returnedText)
        end)
        
        it("should handle multiple preambles and trims", function()
            local returnedText = nil
            
            api.correctText("raw text", function(text)
                returnedText = text
            end)
            
            local lastCall = mock_hs.getLastCall("task_new")
            local task = lastCall.task
            
            local mockResponse = '{"choices":[{"message":{"content":"Here is the text: \\n\\nResult:  Fixed text  "}}]}'
            local stdOut = mockResponse .. "\nHTTP_STATUS:200"
            
            task._callback(0, stdOut, "")
            
            assert.are.equal("Fixed text", returnedText)
        end)
    end)
end)
