#!/bin/bash

# Setup Script für Model Testing Framework
# Erstellt .env Datei und installiert Dependencies

set -e

cd "$(dirname "$0")"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Model Testing Framework - Setup                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 ist nicht installiert!"
    echo "   Install: brew install python3"
    exit 1
fi

echo "✓ Python 3 found: $(python3 --version)"
echo ""

# Install dependencies
echo "📦 Installing dependencies..."
pip3 install -r requirements.txt
echo "✓ Dependencies installed"
echo ""

# Setup .env
if [ -f ".env" ]; then
    echo "⚠️  .env file already exists. Do you want to overwrite it? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Keeping existing .env file"
        exit 0
    fi
fi

echo "📝 Creating .env file..."
cp .env.example .env

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  ✓ Setup complete!                                            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "1. Edit .env file with your API credentials:"
echo "   ${EDITOR:-nano} .env"
echo ""
echo "   Required settings:"
echo "   - LLM_API_KEY=your-api-key-here"
echo "   - LLM_API_BASE_URL=https://api.yourprovider.com/v1"
echo ""
echo "2. Test your configuration:"
echo "   ./run_model_tests.sh --list"
echo ""
echo "3. Run tests:"
echo "   ./run_model_tests.sh"
echo ""
echo "4. Or auto-discover and test all models:"
echo "   ./run_model_tests.sh --auto-discover"
echo ""
