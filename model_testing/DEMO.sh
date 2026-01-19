#!/bin/bash
# Quick Demo - Shows what the framework does without running actual tests

cat << 'EOF'

╔════════════════════════════════════════════════════════════════════════════╗
║                    🧪 DICTATOR MODEL TESTING FRAMEWORK                     ║
║                                                                            ║
║  Evaluiere LLM-Modelle für Text-Korrektur nach Whisper-Transkription     ║
╚════════════════════════════════════════════════════════════════════════════╝

📊 WAS WIRD GETESTET?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Qualität      → Füllwörter entfernt? Interpunktion korrekt? Format erkannt?
✓ Geschwindigkeit → Echte TPS (Tokens/Sekunde) & Latenz
✓ Kosten        → Präzise Berechnung pro Test ($0.00001 - $0.001)
✓ Konsistenz    → Gleiche Qualität über mehrere Runs?

🎯 TEST-SZENARIEN (5 Cases)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1️⃣  Normale Diktat      → "äh also ich denke wir sollten äh..."
2️⃣  E-Mail Format       → Erkennt Betreff, Anrede, Grußformel
3️⃣  Technischer Prompt  → "Erstelle Python Skript das äh..."
4️⃣  Listen/Notizen      → Aufzählungen mit Spezifikationen
5️⃣  Mixed Language      → Deutsch + Englisch Tech-Begriffe

📦 10 VORKONFIGURIERTE MODELLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Model                          Speed    Cost/Test    Recommendation
────────────────────────────────────────────────────────────────────────────
Llama 3.1 8B Instant          840 TPS   $0.000045   ⭐ Best value
GPT OSS 20B 128k             1000 TPS   $0.000120   ⚡ Fastest
GPT OSS 120B 128k             500 TPS   $0.000240   ✨ Best quality
Llama 4 Scout                 594 TPS   $0.000090   🎯 Balanced
Qwen3 32B                     662 TPS   $0.000350   🌍 Multilingual
... und 5 weitere

🚀 QUICK START
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 1. Setup
cd model_testing
pip3 install -r requirements.txt

# 2. Set API Key (CROC oder OpenAI-kompatible API)
export LLM_API_KEY="your-api-key-here"

# 3a. Alle Modelle testen (~20 Min, ~$0.02)
./run_model_tests.sh

# 3b. Oder nur top 3 Modelle (~5 Min, ~$0.005)
python3 model_test.py --models \
  "llama-3.1-8b-instant-128k" \
  "gpt-4o-mini-2024-07-18" \
  "llama-4-scout-17bx16e-128k"

📊 BEISPIEL OUTPUT
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Testing: Llama 3.1 8B Instant 128k
  Run 1/3: normal_dictation... ✓ 892ms, 845 TPS, $0.000043
  Run 2/3: email...           ✓ 1050ms, 780 TPS, $0.000051
  Run 3/3: prompt...          ✓ 920ms, 820 TPS, $0.000045
  ...

═══════════════════════════════════════════════════════════════════════════
                        TEST RESULTS SUMMARY
═══════════════════════════════════════════════════════════════════════════

Model                          Quality    Speed      Cost         Success
───────────────────────────────────────────────────────────────────────────
Llama 3.1 8B Instant          85.3/100   840 TPS    $0.000045    15/15 ✓
GPT OSS 20B 128k              92.1/100   1000 TPS   $0.000120    15/15 ✓
Llama 4 Scout                 88.7/100   594 TPS    $0.000090    15/15 ✓

🏆 RECOMMENDATIONS:

🏆 Best Overall: Llama 3.1 8B Instant 128k (Score: 0.87)
   → Quality: 85.3/100 | Speed: 840 TPS | Cost: $0.000045

✨ Best Quality: GPT OSS 20B 128k (92.1/100)
⚡ Fastest: GPT OSS 20B 128k (1000 TPS)
💰 Cheapest: Llama 3.1 8B Instant 128k ($0.000045)

Results saved to: test_results.json

🔧 KONFIGURATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

models_config.json       → Modelle, Preise, Provider konfigurieren
test_cases.json          → Test-Szenarien anpassen/erweitern
models_config.croc_example.json → CROC API Template

Provider wechseln? Einfach in models_config.json:
{
  "providers": {
    "your_provider": {
      "base_url": "https://api.yourprovider.com/v1",
      "auth_header": "Authorization",
      "auth_prefix": "Bearer"
    }
  }
}

📚 DOKUMENTATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

README.md     → Vollständige Dokumentation
EXAMPLES.md   → 11 praktische Beispiele
models_config.croc_example.json → CROC API Setup

💡 NÜTZLICHE BEFEHLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Nur günstigste Modelle
python3 model_test.py --models \
  "llama-3.1-8b-instant-128k" \
  "llama-guard-4-128-128k"

# Ergebnisse analysieren (requires jq)
cat test_results.json | jq '.statistics | 
  to_entries | 
  sort_by(.value.quality_score) | 
  reverse | 
  .[0:3]'

# Custom output file
python3 model_test.py --output my_results.json

🎯 USE CASES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✓ Finde das beste Modell für Dictator Correction
✓ Vergleiche verschiedene API Provider
✓ Teste custom System Prompts
✓ Benchmarke neue Modell-Versionen
✓ Cost-Optimization für Production
✓ A/B Testing verschiedener Konfigurationen

📈 ERWARTETE ERGEBNISSE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Basierend auf den Specs erwarten wir:
→ Llama 3.1 8B Instant: Bestes Preis/Leistungsverhältnis
→ GPT OSS 120B: Höchste Qualität, aber teurer
→ GPT OSS 20B: Bester Speed, gute Quality
→ Qwen3 32B: Excellent für Multilingual

🚨 WICHTIG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  API Key niemals committen!
⚠️  Kosten im Auge behalten (default config: ~$0.02 für alle Tests)
⚠️  Rate Limits beachten (Framework hat automatisches Delay)
✓  test_results.json ist in .gitignore

╔════════════════════════════════════════════════════════════════════════════╗
║  📖 Mehr Infos: README.md & EXAMPLES.md                                   ║
║  🐛 Issues? Check EXAMPLES.md → Troubleshooting Section                   ║
║  💬 Questions? See model_testing/README.md                                ║
╚════════════════════════════════════════════════════════════════════════════╝

EOF
