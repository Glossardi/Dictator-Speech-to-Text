# Makefile for Dictator Project
# Provides convenient commands for testing, installation, and development

.PHONY: help test test-unit test-watch install update uninstall clean setup-dev

# Default target: show help
help:
	@echo "Dictator - Makefile Commands"
	@echo "============================"
	@echo ""
	@echo "Installation & Management:"
	@echo "  make install      - Install Dictator to Hammerspoon (with backup)"
	@echo "  make update       - Update to latest version (with backup)"
	@echo "  make uninstall    - Remove Dictator from Hammerspoon"
	@echo ""
	@echo "Development & Testing:"
	@echo "  make test         - Run all tests"
	@echo "  make test-unit    - Run only unit tests"
	@echo "  make test-watch   - Run tests in watch mode (auto-rerun on file changes)"
	@echo "  make setup-dev    - Install development dependencies (busted)"
	@echo "  make clean        - Remove test artifacts"
	@echo ""

# Install development dependencies
setup-dev:
	@echo "Installing development dependencies..."
	@command -v luarocks >/dev/null 2>&1 || { echo "Error: LuaRocks not found. Install with: brew install luarocks"; exit 1; }
	luarocks install --local busted
	@echo ""
	@echo "Setup complete! Run 'make test' to run tests."

# Run all tests
test:
	@echo "Running all tests..."
	@./scripts/run_tests.sh

# Run only unit tests
test-unit:
	@echo "Running unit tests..."
	@./scripts/run_tests.sh --output=plainTerminal --pattern=_spec spec/unit/

# Run tests in watch mode (requires entr: brew install entr)
test-watch:
	@command -v entr >/dev/null 2>&1 || { echo "Error: entr not found. Install with: brew install entr"; exit 1; }
	@echo "Watching for file changes... (Ctrl+C to stop)"
	@find . -name "*.lua" | entr -c make test-unit

# Install to Hammerspoon (recommended - uses install script with backup)
install:
	@./install.sh

# Update to latest version (with backup)
update:
	@./scripts/update.sh

# Uninstall from Hammerspoon
uninstall:
	@./scripts/uninstall.sh

# Quick install (copy files only, no checks or backup - for developers)
quick-install:
	@echo "Quick installing to Hammerspoon (no backup)..."
	@mkdir -p ~/.hammerspoon
	@cp -v *.lua ~/.hammerspoon/
	@echo ""
	@echo "Installation complete! Reload Hammerspoon config."

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	rm -rf luacov.*.out
	@echo "Clean complete!"
