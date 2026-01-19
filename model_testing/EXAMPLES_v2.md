# Model Testing - Quick Examples (Updated for v2.0)

## 🆕 Neue Features in v2.0

### .env Konfiguration + Auto-Discovery

## Setup (einmalig)

```bash
# 1. Automatisches Setup
./setup.sh

# 2. .env editieren
nano .env

# 3. Fertig! Tests starten
./run_model_tests.sh --auto-discover
```

## 1. Auto-Discovery aller Modelle

```bash
# Setup
cp .env.example .env
nano .env  # API Key eintragen

# Automatisch alle verfügbaren Modelle finden und testen
./run_model_tests.sh --auto-discover

# Duration: Abhängig von Anzahl Modelle
# Cost: ~$0.001 pro Modell × Anzahl Modelle
```

## 2. Liste verfügbare Modelle

```bash
# Zeige alle verfügbaren Modelle vom Provider
./run_model_tests.sh --list

# Oder
python3 model_test.py --list-models --auto-discover

# Output:
# 1. Llama 3.1 8B Instant
#    ID: llama-3.1-8b-instant-128k
#    Speed: ~840 TPS
#    Price: $0.050 / $0.080 per 1M tokens
# ...
```

## 3. Teste spezifische Modelle (nach Name)

```bash
# Partial name match - findet alle Modelle mit "llama" im Namen
python3 model_test.py --model-names "llama"

# Mehrere Namen
python3 model_test.py --model-names "llama" "gpt-4o" "qwen"

# Duration: ~2-3 min pro Modell
```

## 4. .env Konfiguration nutzen

```bash
# In .env setzen:
# LLM_MODELS=llama-3.1-8b-instant-128k,gpt-4o-mini-2024-07-18

# Dann einfach:
./run_model_tests.sh

# Testet nur die Modelle aus .env
```

## 5. Vollständiger Workflow

```bash
# 1. Setup
./setup.sh

# 2. .env konfigurieren
cat > .env << EOF
LLM_API_KEY=sk-your-groq-key-here
LLM_API_BASE_URL=https://api.groq.com/v1
LLM_PROVIDER_NAME=Groq
TEST_RUNS_PER_CASE=3
EOF

# 3. Liste Modelle
./run_model_tests.sh --list

# 4. Teste beste Modelle
python3 model_test.py --model-names "llama-3.1-8b" "gpt-4o-mini"

# 5. Analysiere Ergebnisse
cat test_results.json | jq '.statistics'
```

## 6. Ohne models_config.json arbeiten

```bash
# Komplett über .env + Auto-Discovery
# KEINE models_config.json nötig!

cp .env.example .env
# Editiere .env
./run_model_tests.sh --auto-discover
```

## 7. Verschiedene Provider testen

```bash
# Groq API
cat > .env << EOF
LLM_API_KEY=your-groq-key
LLM_API_BASE_URL=https://api.groq.com/v1
LLM_PROVIDER_NAME=Groq
EOF
python3 model_test.py --auto-discover

# OpenAI
cat > .env << EOF
LLM_API_KEY=sk-...
LLM_API_BASE_URL=https://api.openai.com/v1
LLM_PROVIDER_NAME=OpenAI
EOF
python3 model_test.py --auto-discover

# DeepInfra
cat > .env << EOF
LLM_API_KEY=your-deepinfra-key
LLM_API_BASE_URL=https://api.deepinfra.com/v1/openai
LLM_PROVIDER_NAME=DeepInfra
EOF
python3 model_test.py --auto-discover
```

## 8. Command-line Override

```bash
# .env ignorieren und direkt Parameter übergeben
python3 model_test.py \
  --api-key "sk-..." \
  --api-url "https://api.example.com/v1" \
  --provider-name "MyProvider" \
  --auto-discover
```

## 9. Schneller Test (1 Run)

```bash
# In .env:
TEST_RUNS_PER_CASE=1

# Dann:
./run_model_tests.sh --model-names "llama-3.1-8b"

# 3x schneller als default (3 runs)
```

## 10. Nur Best-of-Class testen

```bash
# Günstigste
python3 model_test.py --model-names "llama-3.1-8b-instant"

# Schnellste
python3 model_test.py --model-names "gpt-4o-mini" "gpt-oss-20b"

# Beste Qualität
python3 model_test.py --model-names "gpt-oss-120b" "qwen3-32b"
```

## 11. Batch-Testing mehrerer Provider

```bash
# test_all_providers.sh
#!/bin/bash

PROVIDERS=(
  "Groq:https://api.groq.com/v1:groq-key"
  "OpenAI:https://api.openai.com/v1:openai-key"
  "DeepInfra:https://api.deepinfra.com/v1/openai:deepinfra-key"
)

for provider in "${PROVIDERS[@]}"; do
  IFS=':' read -r name url key <<< "$provider"
  
  echo "Testing $name..."
  python3 model_test.py \
    --api-key "$key" \
    --api-url "$url" \
    --provider-name "$name" \
    --auto-discover \
    --output "results_${name}.json"
done
```

## 📊 Praktische Analyse-Befehle

### Mit .env Results

```bash
# Beste 3 nach Quality
cat test_results.json | jq '.statistics | to_entries | 
  sort_by(.value.quality_score) | 
  reverse | .[0:3] | 
  .[] | "\(.value.model_name): \(.value.quality_score)"'

# Günstigste 3
cat test_results.json | jq '.statistics | to_entries | 
  sort_by(.value.avg_cost_per_test) | 
  .[0:3] | 
  .[] | "\(.value.model_name): $\(.value.avg_cost_per_test)"'

# Schnellste 3
cat test_results.json | jq '.statistics | to_entries | 
  sort_by(.value.avg_tps) | 
  reverse | .[0:3] | 
  .[] | "\(.value.model_name): \(.value.avg_tps) TPS"'
```

## 🎯 Typische Use Cases

### Use Case 1: Finde bestes Modell für Dictator

```bash
# 1. Setup
./setup.sh && nano .env

# 2. Alle Modelle testen
./run_model_tests.sh --auto-discover

# 3. Ergebnisse ansehen
# → Best Overall wird empfohlen

# 4. Top 3 nochmal mit mehr Runs testen
echo "TEST_RUNS_PER_CASE=5" >> .env
python3 model_test.py --model-names "top-model-1" "top-model-2" "top-model-3"
```

### Use Case 2: Vergleiche Provider

```bash
# test_providers.sh
for provider in "Groq" "OpenAI" "DeepInfra"; do
  # .env für jeden Provider anpassen
  python3 model_test.py --auto-discover --output "results_${provider}.json"
done

# Vergleiche
for file in results_*.json; do
  echo "$file:"
  cat "$file" | jq '.statistics | length'
  cat "$file" | jq '[.statistics[].avg_cost_per_test] | add / length'
done
```

### Use Case 3: Budget-Testing

```bash
# Nur günstigste Modelle testen
# In .env: LLM_MODELS=llama-3.1-8b-instant-128k,llama-guard-4-128-128k
./run_model_tests.sh

# Gesamtkosten prüfen
cat test_results.json | jq '.statistics | [.[].total_cost_usd] | add'
```

## 🚨 Troubleshooting

### .env wird nicht gelesen

```bash
# Prüfen ob .env existiert
ls -la .env

# Prüfen ob python-dotenv installiert ist
pip3 install python-dotenv

# Manuell laden
export $(cat .env | xargs)
```

### Auto-Discovery funktioniert nicht

```bash
# Manuell /models endpoint testen
curl -H "Authorization: Bearer $LLM_API_KEY" \
  https://api.groq.com/v1/models

# Falls API nicht OpenAI-kompatibel:
# → Nutze models_config.json statt Auto-Discovery
cp models_config.groq_example.json models_config.json
```

### API Key committed

```bash
# .env aus Git entfernen
git rm --cached .env
git commit -m "Remove .env from tracking"

# Prüfen ob in .gitignore
grep ".env" .gitignore
```

## 💡 Pro-Tips

1. **Immer .env nutzen** statt API Keys in Commands
2. **--list zuerst** um verfügbare Modelle zu sehen
3. **Partial matches** sind case-insensitive ("LLAMA" findet "llama")
4. **TEST_RUNS_PER_CASE=1** für schnelle Tests
5. **.env nicht committen** (ist in .gitignore)

## 📈 Performance Tuning

```bash
# Schnelle Tests
TEST_RUNS_PER_CASE=1
TEST_TIMEOUT_SECONDS=15

# Gründliche Tests
TEST_RUNS_PER_CASE=5
TEST_TIMEOUT_SECONDS=60

# Production-Ready Tests
TEST_RUNS_PER_CASE=10
TEST_TEMPERATURE=0.0  # Deterministisch
```
