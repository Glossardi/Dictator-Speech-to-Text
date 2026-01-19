#!/bin/bash

# Quick Start Script für Model Testing
# Usage: ./run_model_tests.sh [API_KEY] [MODEL_IDS...]

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
if ! python3 -c "import requests" 2>/dev/null; then
    echo "📦 Installing dependencies..."
    pip3 install -r requirements.txt
fi

# Get API key
API_KEY="${1:-${LLM_API_KEY}}"

if [ -z "$API_KEY" ]; then
    echo "❌ Kein API Key angegeben!"
    echo ""
    echo "Usage:"
    echo "  ./run_model_tests.sh YOUR_API_KEY"
    echo "  OR"
    echo "  export LLM_API_KEY=YOUR_API_KEY && ./run_model_tests.sh"
    echo ""
    exit 1
fi

shift 2>/dev/null || true

# Run tests
echo "🚀 Starting tests..."
echo ""

if [ $# -gt 0 ]; then
    # Specific models
    python3 model_test.py --api-key "$API_KEY" --models "$@"
else
    # All models
    python3 model_test.py --api-key "$API_KEY"
fi

echo ""
echo "✅ Tests complete! Results saved to test_results.json"
