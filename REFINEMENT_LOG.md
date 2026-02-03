# Dokumentation der Versuchsreihe zur Prompt-Optimierung

## Zielsetzung
Das Ziel war es, den System-Prompt für den "Correction Mode" von Dictator so zu verfeinern, dass Modelle wie Mistral (speziell `ministral-8b-2512`) Transkripte bereinigen, ohne den ursprünglichen Wortlaut zu verändern oder künstliche Formatierungen (Markdown, Gedankenstriche) hinzuzufügen.

## Durchgeführte Schritte
1.  **Test-Setup**: Erstellung von automatisierten Test-Skripten (`validate_prompt.py`) und einem Datensatz mit Gold-Standard-Beispielen (`test_data/transcribed_examples.json`).
2.  **Iterative Verfeinerung**: Über 20 Iterationen des Prompts wurden gegen verschiedene Modelle getestet. Es wurden Ansätze von "Persona-basiert" (Stenograf) bis "Literal-Filter" (rein negativ-basiert) ausprobiert.
3.  **Metriken**: Bewertung der Ergebnisse durch stärkere Modelle (GPT-4o) zur Prüfung der Worttreue und Fehlerfreiheit.

## Ergebnisse und Erkenntnisse
*   **Modell-Eigensinn**: Kleinere Modelle (`8B` Klasse) tendieren stark dazu, Text "aufzuhübschen" oder grammatikalisch zu korrigieren, selbst wenn explizit ein Verbatim-Output gefordert wird.
*   **Übersetzungs-Bias**: Bei gemischtsprachigen Transkripten (Denglisch) neigen die Modelle dazu, englische Begriffe im deutschen Kontext einzudeutschen.
*   **Formatierungs-Herausforderung**: Die Balance zwischen "keine künstliche Formatierung" und "sinnvolle Listen-Formatierung bei Bedarf" ist schwer zu halten, da Modelle oft entweder gar nichts oder alles formatieren.

## Fazit
Die Versuche, einen universell stabilen Prompt für hochgradig "eigensinnige" Instruktionsmodelle zu finden, die minimalinvasiv arbeiten, sind zum jetzigen Zeitpunkt in dieser Umgebung gescheitert. Der Whisper-Output allein ist oft bereits sehr präzise, und die zusätzlichen Fehler, die durch den Korrektur-Modus eingeführt wurden (Veränderung des Wortlauts), überstiegen den Nutzen der Bereinigung.

Die entsprechenden Test-Skripte und temporären Daten wurden aus dem Repository entfernt. Das Projekt wurde auf einen stabilen Stand zurückgesetzt.
