#!/bin/bash
# run_tests.sh - Convenience script to run tests with proper LuaRocks PATH

# Set up LuaRocks environment
eval "$(luarocks path --bin)"

# Check if busted is available
if ! command -v busted &> /dev/null; then
    echo "Error: busted not found"
    echo "Run: make setup-dev"
    exit 1
fi

# Run busted with all arguments passed to script
busted "$@"
