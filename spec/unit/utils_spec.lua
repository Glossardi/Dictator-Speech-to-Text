-- spec/unit/utils_spec.lua
-- Unit tests for utils module

describe("utils module", function()
    local utils
    local mock_hs
    
    before_each(function()
        -- Setup mock Hammerspoon environment
        mock_hs = require("spec.support.mock_hs")
        mock_hs.reset()
        mock_hs.setup()
        
        -- Reload utils module
        package.loaded["utils"] = nil
        utils = require("utils")
    end)
    
    after_each(function()
        mock_hs.teardown()
    end)
    
    describe("file_exists", function()
        it("should return true for existing files", function()
            -- Create a temporary test file
            local tempFile = os.tmpname()
            local f = io.open(tempFile, "w")
            f:write("test")
            f:close()
            
            assert.is_true(utils.file_exists(tempFile))
            
            -- Clean up
            os.remove(tempFile)
        end)
        
        it("should return false for non-existing files", function()
            assert.is_false(utils.file_exists("/path/to/nonexistent/file.txt"))
        end)
        
        it("should handle nil input", function()
            assert.is_false(utils.file_exists(nil))
        end)
    end)
    
    describe("get_file_size", function()
        it("should return file size via mock", function()
            local size = utils.get_file_size("/fake/path/test.mp3")
            -- Mock returns 100KB by default
            assert.are.equal(1024 * 100, size)
        end)
        
        it("should track fs.attributes calls", function()
            local filepath = "/test/file.mp3"
            utils.get_file_size(filepath)
            
            assert.are.equal(1, mock_hs.getCallCount("fs_attributes"))
            local call = mock_hs.getLastCall("fs_attributes")
            assert.are.equal(filepath, call.filepath)
        end)
    end)
    
    describe("get_temp_file_path", function()
        it("should generate unique temp file paths", function()
            local path1 = utils.get_temp_file_path("mp3")
            local path2 = utils.get_temp_file_path("mp3")
            
            -- Paths should be different (due to UUID)
            assert.is_string(path1)
            assert.is_string(path2)
            assert.are_not.equal(path1, path2)
        end)
        
        it("should use correct file extension", function()
            local path = utils.get_temp_file_path("mp3")
            assert.is_true(path:match("%.mp3$") ~= nil)
        end)
        
        it("should default to mp3 extension", function()
            local path = utils.get_temp_file_path()
            assert.is_true(path:match("%.mp3$") ~= nil)
        end)
        
        it("should include mock UUID in path", function()
            local path = utils.get_temp_file_path()
            assert.is_true(path:match("mock%-uuid%-12345") ~= nil)
        end)
    end)
    
    describe("getCurrentContext", function()
        it("should return basic context XML", function()
            local context = utils.getCurrentContext()
            assert.is_string(context)
            assert.is_true(context:find("<context>") ~= nil)
            assert.is_true(context:find("<app_name>Mock App</app_name>") ~= nil)
            assert.is_true(context:find("<window_title>Mock Window</window_title>") ~= nil)
        end)
        
        it("should include surrounding text from AX", function()
            local context = utils.getCurrentContext()
            assert.is_true(context:find("<surrounding_text_readonly>Mock AX Text Content") ~= nil)
        end)
        
        it("should use clipboard fallback for hard-case apps if AX fails", function()
            -- Modify mock to fail AX but be a hard-case app
            hs.window.focusedWindow = function()
                return {
                    title = function() return "VS Code" end,
                    application = function()
                        return {
                            name = function() return "Code" end,
                            bundleID = function() return "com.microsoft.VSCode" end
                        }
                    end
                }
            end
            
            -- AX returns nothing
            hs.axuielement.systemWideElement = function()
                return { attributeValue = function() return nil end }
            end
            
            local context = utils.getCurrentContext()
            assert.is_true(context:find("<context_method>clipboard_fallback</context_method>") ~= nil)
            assert.is_true(context:find("<surrounding_text_readonly>Mock Clipboard Content") ~= nil)
            
            -- Verify keystrokes were sent
            assert.is_true(mock_hs.getCallCount("eventtap_keystroke") >= 2)
        end)
    end)
end)
