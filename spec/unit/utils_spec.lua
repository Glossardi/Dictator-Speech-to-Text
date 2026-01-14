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
            local size = utils.get_file_size("/fake/path/test.flac")
            -- Mock returns 100KB by default
            assert.are.equal(1024 * 100, size)
        end)
        
        it("should track fs.attributes calls", function()
            local filepath = "/test/file.flac"
            utils.get_file_size(filepath)
            
            assert.are.equal(1, mock_hs.getCallCount("fs_attributes"))
            local call = mock_hs.getLastCall("fs_attributes")
            assert.are.equal(filepath, call.filepath)
        end)
    end)
    
    describe("get_temp_file_path", function()
        it("should generate unique temp file paths", function()
            local path1 = utils.get_temp_file_path("flac")
            local path2 = utils.get_temp_file_path("flac")
            
            -- Paths should be different (due to UUID)
            assert.is_string(path1)
            assert.is_string(path2)
            assert.are_not.equal(path1, path2)
        end)
        
        it("should use correct file extension", function()
            local path = utils.get_temp_file_path("mp3")
            assert.is_true(path:match("%.mp3$") ~= nil)
        end)
        
        it("should default to flac extension", function()
            local path = utils.get_temp_file_path()
            assert.is_true(path:match("%.flac$") ~= nil)
        end)
        
        it("should include mock UUID in path", function()
            local path = utils.get_temp_file_path()
            assert.is_true(path:match("mock%-uuid%-12345") ~= nil)
        end)
    end)
end)
