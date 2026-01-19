#!/bin/bash

# Quick Start Script für Model Testing
# Usage: ./run_model_tests.sh [OPTIONS]

set -e

cd "$(dirname "$0")"

echo "🧪 Dictator Model Testing Framework"
echo "===================================="
echo ""

# Check Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 ist nicht installiert!"
    echo "   Install: brew install python3"
    exit 1
fi

# Check/Install dependencies
if ! python3 -c "import requests" 2>/dev/null || ! python3 -c "import dotenv" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip3 install -r requirements.txt
    echo ""
fi

# Check for .env file
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found!"
    echo ""
    echo "Setup steps:"
    echo "  1. cp .env.example .env"
    echo "  2. Edit .env and add your API key and provider URL"
    echo "  3. Run this script again"
    echo ""
    echo "Or use command-line arguments:"
    echo "  python3 model_test.py --api-key YOUR_KEY --api-url https://api.example.com/v1 --auto-discover"
    echo ""
    exit 1
fi

# Source .env for display purposes
source .env 2>/dev/null || true

echo "📝 Configuration:"
echo "   Provider: ${LLM_PROVIDER_NAME:-Not set}"
echo "   Base URL: ${LLM_API_BASE_URL:-Not set}"
echo "   API Key: ${LLM_API_KEY:0:20}..." 
echo ""

# Check if we should list models
if [ "$1" == "--list" ] || [ "$1" == "--list-models" ]; then
    python3 model_test.py --list-models
    exit 0
fi

# Run tests
echo "🚀 Starting tests..."
echo ""

# Parse arguments
if [ $# -eq 0 ]; then
    # No arguments - check if LLM_MODELS is set in .env
    if [ -n "$LLM_MODELS" ]; then
        echo "Using models from .env: $LLM_MODELS"
        IFS=',' read -ra MODEL_ARRAY <<< "$LLM_MODELS"
        python3 model_test.py --model-names "${MODEL_ARRAY[@]}"
    else
        # Auto-discover all models
        echo "Auto-discovering all available models..."
        python3 model_test.py --auto-discover
    fi
else
    # Pass all arguments to model_test.py
    python3 model_test.py "$@"
fi

echo ""
echo "✅ Tests complete! Results saved to test_results.json"
