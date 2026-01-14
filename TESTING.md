# Testing Guide for Dictator

This document provides comprehensive information about testing the Dictator project.

## Overview

Dictator uses **[Busted](https://lunarmodules.github.io/busted/)**, a mature and feature-rich testing framework for Lua, to ensure code quality and prevent regressions.

### Test Coverage

The test suite covers:
- ✅ Configuration management (API keys, settings, validation)
- ✅ Utility functions (file operations, temp files)
- ✅ Rate limiting (token bucket algorithm)
- ✅ API validation (API keys, file sizes, retries)
- ✅ Mock Hammerspoon environment (no macOS required)

## Quick Start

```bash
# 1. Install test dependencies
make setup-dev

# 2. Run all tests
make test

# 3. Run tests in watch mode (auto-rerun on changes)
make test-watch  # requires: brew install entr
```

## Running Tests

### Via Makefile (Recommended)

```bash
# Run all tests
make test

# Run only unit tests
make test-unit

# Watch mode (requires entr)
make test-watch

# Clean test artifacts
make clean
```

### Via Busted Directly

```bash
# All tests with verbose output
busted --verbose

# Specific test file
busted spec/unit/config_spec.lua

# With custom output format
busted --output=tap        # TAP format
busted --output=json       # JSON format
busted --output=junit      # JUnit XML

# Run specific tag
busted --tags=unit

# Exclude tests by pattern
busted --exclude-pattern=integration
```

## Test Structure

```
spec/
├── support/
│   └── mock_hs.lua          # Mock Hammerspoon APIs
└── unit/
    ├── config_spec.lua       # Config module tests (80+ assertions)
    ├── utils_spec.lua        # Utility tests
    ├── rate_limiter_spec.lua # Rate limiting tests (token bucket)
    └── api_spec.lua          # API validation tests
```

## Mock Hammerspoon Environment

Tests run **without Hammerspoon** using a comprehensive mock layer that simulates:

- `hs.settings` - Persistent key-value storage
- `hs.alert` - Alert dialogs
- `hs.task` - External process execution
- `hs.dialog` - User prompts
- `hs.fs` - File system operations
- `hs.host` - System information
- `hs.logger` - Logging
- `hs.timer` - Timers and time tracking
- `hs.pasteboard` - Clipboard operations

### Using Mocks in Tests

```lua
describe("my module", function()
    local mock_hs
    local myModule
    
    before_each(function()
        -- Setup mocks
        mock_hs = require("spec.support.mock_hs")
        mock_hs.reset()
        mock_hs.setup()
        
        -- Reload module
        package.loaded["myModule"] = nil
        myModule = require("myModule")
    end)
    
    after_each(function()
        mock_hs.teardown()
    end)
    
    it("should use mock settings", function()
        -- Mock automatically tracks calls
        myModule.saveSetting("key", "value")
        
        assert.are.equal(1, mock_hs.getCallCount("settings_set"))
        assert.are.equal("value", mock_hs.settingsStore["key"])
    end)
end)
```

## Writing Tests

### BDD-Style Syntax

Busted uses a BDD (Behavior-Driven Development) style:

```lua
describe("Feature Name", function()
    before_each(function()
        -- Setup code runs before each test
    end)
    
    after_each(function()
        -- Cleanup code runs after each test
    end)
    
    describe("Subfeature", function()
        it("should do something specific", function()
            -- Arrange
            local input = "test"
            
            -- Act
            local result = myFunction(input)
            
            -- Assert
            assert.are.equal("expected", result)
        end)
        
        it("should handle errors", function()
            assert.has_error(function()
                myFunction(nil)
            end)
        end)
    end)
end)
```

### Common Assertions

```lua
-- Equality
assert.are.equal(expected, actual)
assert.are_not.equal(value1, value2)
assert.are.same({1,2,3}, myTable)  -- Deep comparison

-- Type checks
assert.is_true(condition)
assert.is_false(condition)
assert.is_nil(value)
assert.is_not_nil(value)
assert.is_string(value)
assert.is_number(value)
assert.is_table(value)

-- Pattern matching
assert.matches("pattern", string)
assert.is_true(string:match("pattern") ~= nil)

-- Errors
assert.has_error(function() error("boom") end)
assert.has_no_error(function() safeFunction() end)
```

### Mocking Time

```lua
describe("time-dependent function", function()
    local original_os_time
    local mock_time
    
    before_each(function()
        mock_time = 1000
        original_os_time = os.time
        os.time = function() return mock_time end
    end)
    
    after_each(function()
        os.time = original_os_time
    end)
    
    it("should wait correct duration", function()
        local start = os.time()
        mock_time = mock_time + 10
        local elapsed = os.time() - start
        assert.are.equal(10, elapsed)
    end)
end)
```

## Continuous Integration

### GitHub Actions Workflow

Tests run automatically on:
- ✅ Every push to `main` or `develop`
- ✅ Every pull request
- ✅ Manual workflow dispatch

The CI pipeline tests against multiple Lua versions:
- Lua 5.1
- Lua 5.2
- Lua 5.3
- Lua 5.4
- LuaJIT

### Local CI Simulation

```bash
# Test with different Lua versions using Docker
docker run --rm -v $(pwd):/work -w /work \
    nickblah/lua:5.4-luarocks \
    sh -c "luarocks install busted && busted"
```

## Code Quality

### Linting with luacheck

```bash
# Install luacheck
luarocks install luacheck

# Run linter
luacheck .

# With custom rules
luacheck . --globals hs --max-line-length 120
```

Configuration in [.luacheckrc](.luacheckrc):
- Allows `hs` global (Hammerspoon)
- Max line length: 120
- Ignores unused arguments (common in callbacks)

## Best Practices

### ✅ DO

- Write tests for all new features
- Test edge cases and error conditions
- Use descriptive test names
- Keep tests isolated (no shared state)
- Mock external dependencies (Hammerspoon APIs)
- Run tests before committing

### ❌ DON'T

- Test implementation details
- Write tests that depend on execution order
- Mock everything (test real logic when possible)
- Ignore failing tests
- Commit without running tests

## Debugging Tests

### Verbose Output

```bash
# Show all test names and results
busted --verbose

# Show output from print() statements
busted --verbose --defer-print
```

### Run Single Test

```bash
# Run specific file
busted spec/unit/config_spec.lua

# Run tests matching pattern
busted --filter="API Key"
```

### Interactive Debugging

```lua
it("should debug", function()
    print("Value:", inspect(myValue))  -- Use inspect for tables
    assert.are.equal(expected, actual)
end)
```

## Performance

Tests are fast:
- **~100ms** for all unit tests
- No external API calls
- No file I/O (mocked)
- No Hammerspoon runtime

## Troubleshooting

### "module not found" errors

```bash
# Ensure LuaRocks local path is in LUA_PATH
eval $(luarocks path --bin)

# Or use busted from LuaRocks
~/.luarocks/bin/busted
```

### Tests pass locally but fail in CI

- Check Lua version differences
- Verify all dependencies are in rockspec
- Check for platform-specific code

### Mock not working

```lua
-- Ensure mock is setup before requiring modules
mock_hs.setup()  -- Create global hs

-- Then require module that uses hs
local myModule = require("myModule")
```

## Resources

- [Busted Documentation](https://lunarmodules.github.io/busted/)
- [luassert Documentation](https://github.com/lunarmodules/luassert)
- [Lua 5.4 Reference](https://www.lua.org/manual/5.4/)
- [GitHub Actions Lua](https://github.com/leafo/gh-actions-lua)

## Contributing

When adding new features:

1. Write tests first (TDD approach)
2. Implement feature
3. Ensure all tests pass: `make test`
4. Add documentation
5. Submit PR (CI runs automatically)

Questions? Open an issue or discussion on GitHub.
