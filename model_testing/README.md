# Model Testing Framework

Ein umfassendes Test-Framework zur Evaluation verschiedener LLM-Modelle für die Text-Korrektur in Dictator.

## 📋 Übersicht

Dieses Framework testet verschiedene Large Language Models hinsichtlich:
- **Qualität**: Wie gut werden Füllwörter entfernt, Interpunktion korrigiert, und Formatierung erkannt?
- **Geschwindigkeit**: Tokens per Second (TPS) und Latenz
- **Kosten**: Preis pro Test und Gesamtkosten
- **Konsistenz**: Wie stabil sind die Ergebnisse über mehrere Runs?

## 🚀 Quick Start

### 1. Setup (einmalig)

```bash
cd model_testing

# Automatisches Setup
./setup.sh

# Oder manuell:
pip install -r requirements.txt
cp .env.example .env
# Editiere .env mit deinem API Key
```

### 2. Konfiguration

Editiere `.env` Datei:

```bash
# Dein API Key
LLM_API_KEY=sk-your-groq-api-key-here

# Provider Base URL
LLM_API_BASE_URL=https://api.groq.com/v1

# Provider Name (für Anzeige)
LLM_PROVIDER_NAME=Groq

# Optional: Spezifische Modelle (komma-separiert)
# Leer lassen für Auto-Discovery
LLM_MODELS=llama-3.1-8b-instant-128k,gpt-4o-mini-2024-07-18
```

### 3. Testen

```bash
# Auto-discover und teste alle verfügbaren Modelle
./run_model_tests.sh --auto-discover

# Oder nutze .env Konfiguration
./run_model_tests.sh

# Liste verfügbare Modelle
./run_model_tests.sh --list

# Teste spezifische Modelle
python3 model_test.py --model-names "llama" "gpt-4o"
```

## 🎯 Features

### ✨ Neu in Version 2.0

- **🔐 .env Configuration**: API Keys sicher in .env Datei (nicht committed)
- **🔍 Auto-Discovery**: Automatisches Abrufen verfügbarer Modelle über `/models` Endpoint
- **🎯 Flexible Modell-Auswahl**: Nach ID oder Name (partial match)
- **⚙️ Konfigurierbar**: Alle Settings über .env oder Command-line
- **📝 Kein JSON nötig**: Funktioniert komplett über .env ohne models_config.json

### Core Features

✅ Realistische Whisper-Outputs simulieren typische Transkriptionsfehler
✅ Automatische Qualitätsbewertung basierend auf System-Prompt
✅ Farbiger Terminal-Output mit Echtzeit-Ergebnissen
✅ JSON Export für detaillierte Analyse
✅ Empfehlungen: Best Overall, Fastest, Cheapest, Best Quality
✅ Genaues Kostentracking ($0.00001 Precision)
✅ Rate Limiting mit automatischem Delay

## 📖 Verwendung

### Basis-Verwendung

```bash
# Setup
./setup.sh

# .env editieren
nano .env

# Tests starten
./run_model_tests.sh
```

### Auto-Discovery

```bash
# Alle Modelle automatisch vom Provider abrufen
./run_model_tests.sh --auto-discover

# Liste verfügbare Modelle
python3 model_test.py --list-models
```

### Spezifische Modelle testen

```bash
# Nach Namen (partial match)
python3 model_test.py --model-names "llama" "gpt-4o"

# Nach IDs
python3 model_test.py --model-ids "llama-3.1-8b-instant-128k"

# Aus .env LLM_MODELS
# LLM_MODELS=llama-3.1-8b-instant-128k,gpt-4o-mini-2024-07-18
./run_model_tests.sh
```

## 📁 Datei-Struktur

```
model_testing/
├── model_test.py           # Haupt-Test-Skript
├── models_config.json      # Modell-Konfiguration (Preise, Provider, etc.)
├── test_cases.json         # Test-Cases mit realistischen Whisper-Outputs
├── requirements.txt        # Python Dependencies
├── test_results.json       # Output-Datei (generiert)
└── README.md              # Diese Datei
```

## 🧪 Test Cases

Das Framework enthält 5 realistische Test-Szenarien:

1. **normal_dictation**: Normale gesprochene Eingabe mit Füllwörtern
2. **email**: E-Mail-Diktat mit Formatierungsanforderungen
3. **prompt_instruction**: Technischer Prompt/Befehl mit Fachbegriffen
4. **list_notes**: Einkaufsliste/Notizen mit Aufzählungen
5. **mixed_language**: Deutsch-Englisch gemischt (Tech-Kontext)

Jeder Test simuliert typische Whisper-Transkriptions-Fehler:
- Füllwörter (äh, ähm)
- Fehlende Interpunktion
- Selbstkorrekturen
- Wiederholungen

## ⚙️ Konfiguration

### models_config.json

Enthält alle zu testenden Modelle mit:
```json
{
  "id": "model-identifier",
  "name": "Display Name",
  "provider": "groq",
  "speed_tps": 1000,
  "input_price_per_1m": 0.075,
  "output_price_per_1m": 0.30,
  "context_window": 128000
}
```

### Provider hinzufügen/ändern

Im `providers` Abschnitt der `models_config.json`:

```json
{
  "providers": {
    "your_provider": {
      "name": "Your Provider Name",
      "base_url": "https://api.yourprovider.com/v1",
      "auth_header": "Authorization",
      "auth_prefix": "Bearer"
    }
  }
}
```

### Eigene Test-Cases hinzufügen

In `test_cases.json`:

```json
{
  "name": "your_test_case",
  "description": "Beschreibung des Test-Szenarios",
  "whisper_output": "Der Text wie er von Whisper transkribiert wurde äh mit Fehlern",
  "expected_corrections": [
    "Was korrigiert werden sollte"
  ],
  "ideal_output": "Der perfekt korrigierte Text."
}
```

## 📊 Output & Ergebnisse

### Terminal-Output

Das Skript zeigt während der Ausführung:
- Fortschritt jedes einzelnen Tests
- Latenz, TPS und Kosten pro Test
- Farbcodierte Erfolgs-/Fehler-Meldungen

Am Ende wird eine Zusammenfassung angezeigt:
```
TEST RESULTS SUMMARY
==================================================================================
Model                               Quality    Speed        Cost         Latency      Success   
------------------------------------------------------------------------------------
Llama 3.1 8B Instant 128k          85.3/100   840 TPS      $0.000045    950ms        15/15     
GPT OSS 20B 128k                   92.1/100   1000 TPS     $0.000120    780ms        15/15     
...

RECOMMENDATIONS:
🏆 Best Overall: Llama 3.1 8B Instant 128k (Score: 0.87)
✨ Best Quality: GPT OSS 20B 128k (92.1/100)
⚡ Fastest: GPT OSS 20B 128k (1000 TPS)
💰 Cheapest: Llama 3.1 8B Instant 128k ($0.000045 per test)
```

### JSON-Output (test_results.json)

Detaillierte Ergebnisse werden gespeichert:

```json
{
  "metadata": {
    "timestamp": "2026-01-19T...",
    "total_tests": 150,
    "successful_tests": 145,
    "failed_tests": 5
  },
  "results": [
    {
      "model_id": "...",
      "model_name": "...",
      "test_case": "normal_dictation",
      "run_number": 1,
      "input_text": "...",
      "output_text": "...",
      "tokens_prompt": 145,
      "tokens_completion": 98,
      "latency_ms": 892.3,
      "tps": 109.8,
      "cost_usd": 0.000067,
      "success": true
    }
  ],
  "statistics": {
    "model-id": {
      "avg_latency_ms": 875.5,
      "avg_tps": 845.2,
      "quality_score": 87.3,
      "consistency_score": 94.1,
      "total_cost_usd": 0.002145
    }
  }
}
```

## 🎯 Bewertungskriterien

Die Quality-Score wird berechnet basierend auf:

| Kriterium | Gewicht | Beschreibung |
|-----------|---------|--------------|
| Füllwörter entfernt | 20% | äh, ähm, also, etc. sollten weg sein |
| Korrekte Interpunktion | 20% | Satzzeichen richtig gesetzt |
| Format-Erkennung | 25% | E-Mail, Listen, Absätze erkannt |
| Selbstkorrekturen aufgelöst | 15% | Wiederholungen bereinigt |
| Sprache beibehalten | 10% | Keine ungewollten Übersetzungen |
| Kein zusätzlicher Inhalt | 10% | Länge ähnlich, nichts erfunden |

**Score-Interpretation:**
- 90-100: Exzellent - Produktionsreif
- 80-89: Sehr gut - Kleinere Verbesserungen möglich
- 70-79: Gut - Akzeptabel für die meisten Fälle
- 60-69: Ausreichend - Nur für unkritische Anwendungen
- <60: Ungenügend - Nicht empfohlen

## 🔬 Erweiterte Nutzung

### Einzelne Modelle debuggen

```python
from model_test import ModelTester

tester = ModelTester(api_key="your-key")
model = tester.config["models"][0]  # Erstes Modell
test_case = tester.test_cases[0]    # Erster Test-Case

result = tester.run_single_test(model, test_case, 1)
print(f"Input: {result.input_text}")
print(f"Output: {result.output_text}")
print(f"Quality: {tester._evaluate_quality(test_case, result.output_text)}/100")
```

### Eigene Evaluation-Metriken

Die `_evaluate_quality` Methode kann angepasst werden für spezifischere Bewertungen:

```python
def _evaluate_quality(self, test_case: Dict, output: str) -> float:
    # Deine eigene Logik hier
    score = 100.0
    
    # Beispiel: BLEU/ROUGE Score mit ideal_output vergleichen
    # Beispiel: Sentiment-Analyse
    # Beispiel: Named Entity Recognition Präzision
    
    return score
```

## 💡 Best Practices

### Performance-Testing

```bash
# Schneller Test mit wenigen Modellen
python model_test.py --models "llama-3.1-8b-instant-128k" "gpt-4o-mini-2024-07-18"

# Vollständiger Test über Nacht laufen lassen
nohup python model_test.py > test_output.log 2>&1 &
```

### Kosten im Blick behalten

Das Framework berechnet automatisch Kosten. Für große Test-Suites:

```python
# In models_config.json runs_per_case anpassen
"test_config": {
  "runs_per_case": 1,  # Reduziere von 3 auf 1 für schnellere/günstigere Tests
  "timeout_seconds": 30
}
```

**Geschätzte Kosten pro Modell:** ~$0.001 - $0.005 für alle Test-Cases (3 Runs)

### Neue Provider hinzufügen

1. Provider in `models_config.json` definieren
2. Modell mit `"provider": "your_provider"` hinzufügen
3. API Key setzen
4. Testen!

```bash
export LLM_API_KEY="your-new-provider-key"
python model_test.py --models "your-new-model-id"
```

## 🐛 Troubleshooting

### API Timeouts

```json
// models_config.json
"test_config": {
  "timeout_seconds": 60  // Erhöhe bei langsamen Modellen
}
```

### Rate Limiting

```python
# In models_config.json
"test_config": {
  "parallel_requests": false  // Bereits deaktiviert für sequential testing
}
```

Das Skript hat bereits 0.5s Delay zwischen Requests eingebaut.

### Authentifizierung Fehlgeschlagen

Stelle sicher, dass:
1. API Key korrekt ist
2. Provider `auth_header` und `auth_prefix` in config stimmen
3. base_url korrekt ist (mit `/v1` Suffix bei OpenAI-kompatiblen APIs)

### Unerwartete API-Responses

Prüfe ob die API OpenAI-kompatibel ist. Expected response format:

```json
{
  "choices": [{"message": {"content": "..."}}],
  "usage": {
    "prompt_tokens": 100,
    "completion_tokens": 50
  }
}
```

## 📈 Ergebnis-Analyse

### Python-Auswertung

```python
import json
import pandas as pd

with open('test_results.json') as f:
    data = json.load(f)

# Pandas DataFrame erstellen
df = pd.DataFrame(data['results'])

# Analysen
print(df.groupby('model_name')['latency_ms'].describe())
print(df.groupby('test_case')['cost_usd'].sum())

# Visualisierung
import matplotlib.pyplot as plt
df.groupby('model_name')['tps'].mean().plot(kind='bar')
plt.show()
```

## 🤝 Contribution

Neue Test-Cases oder Evaluation-Metriken? Einfach in `test_cases.json` oder `models_config.json` ergänzen und PR erstellen!

## 📝 Changelog

### Version 1.0.0 (2026-01-19)
- Initiales Release
- 10 Modelle vorkonfiguriert
- 5 Test-Cases
- Qualität, Geschwindigkeit, Kosten Metriken
- Farbiger Terminal-Output
- JSON Export

## 📄 License

MIT License - Siehe Projekt-Root LICENSE File
