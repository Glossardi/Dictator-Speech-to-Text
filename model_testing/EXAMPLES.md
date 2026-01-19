# Model Testing - Quick Examples

## 1. Kompletter Test aller Modelle

```bash
cd model_testing

# Set CROC API Key
export LLM_API_KEY="sk-your-croc-api-key-here"

# Run all models (10 models × 5 test cases × 3 runs = 150 total tests)
# Expected duration: ~15-30 minutes
# Expected cost: ~$0.01-0.05 total
./run_model_tests.sh
```

## 2. Schneller Test (nur beste Modelle)

```bash
# Test nur die 3 vielversprechendsten Modelle
export LLM_API_KEY="your-key"
python3 model_test.py --models \
  "llama-3.1-8b-instant-128k" \
  "gpt-4o-mini-2024-07-18" \
  "llama-4-scout-17bx16e-128k"

# Duration: ~5-10 minutes
# Cost: ~$0.003-0.01
```

## 3. Einzelnes Modell debuggen

```bash
# Test nur ein Modell mit allen Cases
export LLM_API_KEY="your-key"
python3 model_test.py --models "llama-3.1-8b-instant-128k"

# Duration: ~2-3 minutes
# Cost: ~$0.001
```

## 4. Eigene CROC API URL verwenden

```bash
# 1. Kopiere die Beispiel-Config
cp models_config.croc_example.json models_config.json

# 2. Editiere models_config.json und ändere:
#    - "base_url": "https://api.croc.com/v1"  <- Deine echte CROC API URL
#    - "id" fields falls die Model IDs anders sind

# 3. Run tests
export LLM_API_KEY="your-croc-key"
python3 model_test.py
```

## 5. Nur bestimmte Test-Cases

Wenn du nur E-Mails oder nur Listen testen willst, editiere `test_cases.json` und kommentiere Cases aus:

```json
{
  "test_cases": [
    {
      "name": "email",
      ...
    }
    // Entferne oder kommentiere andere Cases aus
  ]
}
```

## 6. Schneller Test (nur 1 Run pro Case)

```bash
# Editiere models_config.json:
"test_config": {
  "runs_per_case": 1,  // Statt 3
  ...
}

# Dann normal ausführen
./run_model_tests.sh
```

## 7. Ergebnisse analysieren

Nach dem Test:

```bash
# JSON Results anschauen
cat test_results.json | jq '.statistics'

# Beste Modelle finden
cat test_results.json | jq '.statistics | to_entries | sort_by(.value.quality_score) | reverse | .[0:3]'

# Günstigste Modelle
cat test_results.json | jq '.statistics | to_entries | sort_by(.value.avg_cost_per_test) | .[0:3]'

# Schnellste Modelle
cat test_results.json | jq '.statistics | to_entries | sort_by(.value.avg_tps) | reverse | .[0:3]'
```

## 8. Python-Skript für Custom Analysis

```python
import json
import pandas as pd

# Load results
with open('test_results.json') as f:
    data = json.load(f)

# Create DataFrame
results = pd.DataFrame(data['results'])
stats = pd.DataFrame(data['statistics']).T

# Top 3 models by quality
print("\n🏆 Top 3 by Quality:")
print(stats.nlargest(3, 'quality_score')[['model_name', 'quality_score', 'avg_cost_per_test']])

# Top 3 by speed
print("\n⚡ Top 3 by Speed:")
print(stats.nlargest(3, 'avg_tps')[['model_name', 'avg_tps', 'avg_latency_ms']])

# Best value (quality/cost ratio)
stats['value_score'] = stats['quality_score'] / (stats['avg_cost_per_test'] * 10000)
print("\n💎 Best Value (Quality/Cost):")
print(stats.nlargest(3, 'value_score')[['model_name', 'quality_score', 'avg_cost_per_test', 'value_score']])

# Consistency check
print("\n📊 Most Consistent:")
print(stats.nlargest(3, 'consistency_score')[['model_name', 'consistency_score', 'avg_latency_ms']])
```

## 9. Test mit verschiedenen Temperaturen

```python
# Erstelle eigenes Test-Skript: custom_temp_test.py
from model_test import ModelTester

for temp in [0.0, 0.3, 0.7, 1.0]:
    print(f"\n=== Testing with temperature {temp} ===")
    
    tester = ModelTester(api_key="your-key")
    tester.config["test_config"]["temperature"] = temp
    
    # Test nur ein Modell
    tester.run_all_tests(model_ids=["llama-3.1-8b-instant-128k"])
    tester.save_results(f"results_temp_{temp}.json")
```

## 10. Automatischer Nightly Test

Erstelle Cronjob für tägliche Tests:

```bash
# crontab -e
0 2 * * * cd /Users/Simon/Documents/Dictator/model_testing && export LLM_API_KEY="your-key" && python3 model_test.py --output "results_$(date +\%Y\%m\%d).json" >> test.log 2>&1
```

## 11. Vergleich mit Production-Prompt

Um den aktuell in Dictator verwendeten System-Prompt zu testen:

```bash
# Der Prompt ist bereits in test_cases.json enthalten!
# Er stammt aus config.lua: defaultCorrectionSystemPrompt

# Falls du einen anderen Prompt testen willst:
# 1. Editiere test_cases.json
# 2. Ändere "system_prompt": "Dein neuer Prompt hier"
# 3. Run tests
```

## 📊 Erwartete Ergebnisse

Basierend auf den Modell-Specs vom Screenshot:

| Kategorie | Erwartete Top-Performer |
|-----------|-------------------------|
| **Beste Quality** | GPT OSS 120B, Qwen3 32B |
| **Bester Speed** | Llama 3.1 8B Instant, GPT OSS 20B |
| **Beste Cost-Efficiency** | Llama 3.1 8B Instant |
| **Beste Balance** | Llama 4 Scout, GPT OSS 20B |

## 💡 Empfehlungen nach Test-Typ

- **Production use**: Teste mit `runs_per_case: 3` für Konsistenz
- **Quick evaluation**: Teste mit `runs_per_case: 1` 
- **Budget-conscious**: Starte mit günstigsten Modellen
- **Quality-critical**: Teste alle, sortiere nach quality_score

## 🚨 Troubleshooting

### Rate Limiting
```bash
# Füge Delay zwischen Tests hinzu in model_test.py:
time.sleep(1)  # Statt 0.5 sekunden
```

### API Key Fehler
```bash
# Prüfe ob Key gesetzt ist
echo $LLM_API_KEY

# Oder übergebe direkt
python3 model_test.py --api-key "your-key"
```

### Timeout Errors
```json
// In models_config.json erhöhe:
"test_config": {
  "timeout_seconds": 60  // Statt 30
}
```
