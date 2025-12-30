# Dictator Troubleshooting & Test Guide

## Aktueller Status ✅

Nach der Diagnose:
- ✅ Hammerspoon läuft
- ✅ Alle Module installiert (7/7)
- ✅ API Key konfiguriert (sk-proj...)
- ✅ SoX installiert

## Schritt-für-Schritt Test

### 1. Hammerspoon Console öffnen

1. Klicke auf das Hammerspoon Icon in der Menüleiste
2. Wähle **Console**
3. Lasse das Console-Fenster offen

### 2. Config neu laden

Im Console-Fenster:
```lua
hs.reload()
```

Du solltest sehen:
```
Dictator initialized
Fn key watcher started successfully
(oder: Hotkey bound successfully)
```

### 3. Debug-Info anzeigen

Kopiere diesen Code in die Console:
```lua
dofile("/Users/Simon/Documents/Dictator/debug.lua")
```

Das zeigt dir:
- Module Status
- API Key Validierung
- Hotkey Status
- Rate Limiter Status

### 4. Ersten Test durchführen

1. Klicke in ein Textfeld (z.B. Notes, TextEdit)
2. **Halte Fn-Taste** gedrückt
3. **Sprich etwas** (z.B. "Hello, this is a test")
4. **Lasse Fn-Taste los**
5. Beobachte die Console

#### Erwartete Console-Ausgabe (Normal):

```
Fn key pressed
Recording started
Recording to: /tmp/...
Fn key released
Stopping recording and starting transcription
Recording finished. Exit code: -1
Sending audio to Whisper API
Executing API request...
Audio file: /tmp/...
API Response received. Exit code: 0
Response length: XXX bytes
...
HTTP Status: 200
Transcription successful. Text length: XX
Text copied to clipboard...
Auto-pasting text
```

### 5. Häufige Fehler und Lösungen

#### Fehler: "Recording Error"
**Symptom:** Console zeigt "Recording error" oder "SoX Error"

**Lösung:**
- Mikrofonberechtigung prüfen: System Settings → Privacy & Security → Microphone
- Hammerspoon aktivieren

#### Fehler: "API Error: Invalid API key"
**Symptom:** `HTTP Status: 401` oder "Invalid API key"

**Lösung:**
1. API Key überprüfen: https://platform.openai.com/api-keys
2. Neuen Key erstellen wenn nötig
3. In Dictator Menu: Settings → API Key → Neuen Key eingeben
4. `hs.reload()` in Console

#### Fehler: "Rate limit reached"
**Symptom:** Console zeigt "Rate limit reached. Please wait X seconds."

**Lösung:**
- Das ist normal! OpenAI limitiert auf ~3 Requests pro Minute
- 60 Sekunden warten
- Erneut versuchen

#### Fehler: "Empty response from API"
**Symptom:** Console zeigt "Empty response body from API"

**Mögliche Ursachen:**
1. **Netzwerkproblem:** Internet-Verbindung prüfen
2. **API Key ungültig:** Siehe "Invalid API key" oben
3. **Datei zu groß:** Aufnahme kürzer als 2 Minuten halten

**Debug-Check:**
```bash
cd /Users/Simon/Documents/Dictator
./test_api.sh
```

Das testet direkt den API-Call.

#### Fehler: "No text returned"
**Symptom:** API antwortet, aber kein Text

**Ursachen:**
- Aufnahme war stumm oder zu leise
- Mikrofonpegel prüfen
- Näher am Mikrofon sprechen
- Lauter sprechen

### 6. Manuelle API-Test

Terminal öffnen:
```bash
cd /Users/Simon/Documents/Dictator
./test_api.sh
```

Wenn du aufgefordert wirst zu sprechen:
- Sprich klar und deutlich
- 2-3 Sekunden sprechen
- Test zeigt HTTP Status Code und Antwort

**Erwartete Ausgabe bei Erfolg:**
```
HTTP Status Code: 200
✓ API call successful!
Response:
{
  "text": "Your transcribed text here"
}
```

### 7. Fortgeschrittenes Debugging

#### Rate Limiter Status checken:
```lua
print(hs.inspect(rateLimiter.getStatus()))
```

#### Aktuellen Processing-Status:
```lua
print("Processing:", M.isProcessing)
print("Recording:", audio.isRecording)
```

#### Logger-Level erhöhen:
```lua
log.setLogLevel("debug")
```

## Bekannte Probleme

### Problem: Doppel-Trigger bei schnellem Drücken
**Lösung:** Debouncing ist aktiviert (500ms), sollte nicht mehr auftreten

### Problem: API Timeout
**Symptom:** curl hängt, keine Antwort
**Lösung:** 
- Firewall/VPN prüfen
- OpenAI Status prüfen: https://status.openai.com/
- Netzwerkverbindung testen

### Problem: "Failed to start Fn key watcher"
**Lösung:**
1. System Settings → Privacy & Security → Accessibility
2. Hammerspoon muss aktiviert sein
3. Wenn schon aktiviert: Deaktivieren, neu aktivieren
4. Hammerspoon neu starten

## Support

Wenn das Problem weiterhin besteht:

1. **Console-Log kopieren:**
   - Alle Ausgaben aus dem Console-Fenster kopieren
   - Vom Zeitpunkt "Dictator initialized" bis zum Fehler

2. **Test-Skript ausführen:**
   ```bash
   cd /Users/Simon/Documents/Dictator
   ./diagnose.sh > diagnose_output.txt 2>&1
   ./test_api.sh > api_test_output.txt 2>&1
   ```

3. **Informationen bereitstellen:**
   - macOS Version
   - Hammerspoon Version
   - Console-Log
   - diagnose_output.txt
   - api_test_output.txt
   - Beschreibung was genau nicht funktioniert

## Weitere Tests

### Minimaler Test (ohne API):
```lua
-- In Hammerspoon Console:
audio.startRecording()
-- Warte 2 Sekunden
audio.stopRecording(function(path, err)
    if err then
        print("ERROR:", err)
    else
        print("SUCCESS:", path)
        print("File size:", utils.get_file_size(path))
    end
end)
```

Das testet nur die Aufnahme-Funktionalität ohne API-Call.

