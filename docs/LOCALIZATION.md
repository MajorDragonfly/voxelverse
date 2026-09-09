# Gemeinsame Sprachverwaltung

Stand: 9. September 2026. Vertrag L1. Deutsch (`de`) und Englisch (`en`).
Lars' Auftrag zur Mehrsprachigkeit erweitert die bisherige deutschsprachige
Designvorgabe. Begriffe, Symbole und Datenkennungen bleiben fachlich identisch;
die sichtbaren Bezeichnungen richten sich nach der ausgewählten Sprache.

## Zuständigkeit und Einstieg

`LocaleManager` ist der einzige Sprachdienst. Er registriert die nativen
Godot-Übersetzungen vor den bisherigen Autoloads. Auswahl im Hauptmenü oder
Spiel über **Einstellungen / F8 → Sprache → Übernehmen & speichern**.
**Zurück** verwirft die noch nicht übernommene Sprachauswahl.

Erster Start: Systemsprache; `de-DE`/`de_AT` → Deutsch,
`en-US`/`en_GB` → Englisch. Nicht unterstützte Systeme → Deutsch.
Die ausdrückliche Auswahl hat bei späteren Starts Vorrang. Deutsch ist auch
die Rückfallsprache bei fehlenden englischen Einträgen.

Die Wahl gehört zum Gerät, nicht zum Abenteuer. Eigene Datei
`user://language_settings.cfg`, Abschnitt `language`, Schema 1, Feld
`preference`: `auto`, `de` oder `en`. Erst erfolgreich atomar speichern,
dann live umstellen. Fehlgeschlagene Schreibvorgänge erhalten die aktive
Sprache. Beschädigte Werte verwenden die Systemsprache mit Hinweis;
unbekannte Schema-Versionen bleiben schreibgeschützt.

`LocaleManager.language_changed(locale)` meldet einen tatsächlichen Wechsel.
Keine eigene Pause-, Input-, Audio-, Kampagnen- oder Artenverwaltung ergänzen.
Keine Scene neu laden, um eine Sprache zu wechseln.

## Texte hinzufügen

Einzige editierbare Quelle: `localization/catalog.json` (UTF-8). Pro Text:

```json
{"key": "ANIMAL_ORDER_SENT", "de": "{name} kehrt heim.", "en": "{name} is returning home."}
```

Danach aus dem Projektverzeichnis:

```sh
python3 tools/localization/catalog.py
python3 tools/localization/catalog.py --check
```

Dies erzeugt native `de.po`/`en.po` und die zentrale Ressourcenregistrierung
`catalogs.gd`. Quelle und erzeugte Dateien gemeinsam committen. Die Prüfung
verhindert fehlende Übersetzungen, doppelte Schlüssel und abweichende
Platzhalter. Die PO-Ressourcen werden ausdrücklich vorgeladen und gelangen
auch ohne JSON-Exportfilter in das Spielpaket.

Neue Texte erhalten sprechende, stabile Schlüssel mit Bereichspräfix. Die
deutschen Klartextschlüssel der ersten Lieferung sind ein Anschluss an den
Bestand. Keine pauschale Quellcode-Ersetzung und keine Übersetzung von IDs.
Gleiche Stat-Bedeutung weiter über das gemeinsame Symbol-/Statregister beziehen.

### Statische Controls

```gdscript
label.text = "LANGUAGE_TITLE"
```

Label, Button und vergleichbare Godot-Controls übersetzen ihre Schlüssel
selbst und aktualisieren Text/Layout beim Sprachwechsel. Den unübersetzten
Schlüssel zuweisen; einmalig übersetzten Text nicht dauerhaft zwischenspeichern.

### Dynamische Texte

```gdscript
const Text = preload("res://core/localization/ui_text.gd")

func refresh_text() -> void:
    message.text = Text.format_text("ANIMAL_ORDER_SENT", {"name": animal.name})
```

`refresh_text()` bei Datenänderungen und `language_changed` aufrufen. Die
Formatierung erfolgt einmal gegen die ursprüngliche Vorlage. Platzhalter in
einem Spielernamen werden nicht noch einmal interpretiert. Ganze Sätze
übersetzen, keine Satzteile zusammensetzen. Bestehende `%s`-/`%d`-Vorlagen
werden vor dem Einsetzen übersetzt; neue Vorlagen verwenden benannte Werte.

`Text.plural("SAVE_BACKUPS", "SAVE_BACKUPS_PLURAL", count)` nutzt die
Pluralregeln der PO-Sprache. Im JSON stehen dafür `plural_key`, `de_plural`
und `en_plural` neben den Singulartexten. Die gegenwärtige Generatorform
unterstützt zwei Formen, passend zu Deutsch/Englisch. Für eine Sprache mit
anderer Formenanzahl Generator und Test zuerst erweitern, nicht englische
Grammatikregeln in Spielcode kopieren.

`Text.number(value, decimals=2)` formatiert deutsche Dezimalkommas und englische
Dezimalpunkte ohne unnötige Endnullen. Nicht endliche Zahlen → `—`.
`Text.date_time(unix_time, seconds=false)` verwendet deutsche beziehungsweise
ISO-artige englische Datumsdarstellung und behält die vorhandene UTC-Zeitbasis.
Diese Helfer verändern keine gespeicherten Zahlen. Weitere Sprachen benötigen
ihre jeweilige Zahlen-/Datumsregel und entsprechende Tests.

### Eigene Namen und Daten

```gdscript
name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
name_label.text = animal.name
```

Eigene Abenteuer-, Tier-, Arten-, Bewohner- und Entwurfsnamen sind Daten, keine
Übersetzungsschlüssel. Diese Controls müssen automatische Übersetzung
abschalten, auch wenn ein Name zufällig wie ein vorhandener Menütext lautet.
Art-IDs, Körperteil-IDs, Auftragskennungen, Saves, Messwerte und Ereignis-IDs
niemals übersetzen. Beschreibungen aus bestehenden Modellen erst in der
Darstellung auflösen. Keine übersetzten Modellnamen zurückspeichern.

## Bereits angeschlossen und nächster Anschluss

| Bereich | Stand dieser Lieferung |
| --- | --- |
| Sprachwahl, Startmenü, Spielstartformular | Deutsch/Englisch; Wechsel erhält eingegebenen Namen und Seed |
| Anzeige, Steuerung, Audio-Einstellungen | Bestehende statische Texte; dynamische Tastennamen und Bindungsdialoge angeschlossen |
| Pause, Ladebildschirm, Steuerungshilfe, Einführung | Reguläre Texte angeschlossen; dynamische Steuerungshilfe aktualisiert |
| Speicheransicht | Aktionen, Phasen, Zeitangaben, Anzahl der Sicherungen; Wechsel erhält Auswahl und unfertige Umbenennung |
| Gemeinsame Begriffe/Stats | Übersetzungen im Katalog vorhanden; zusammengesetzte Anzeigen brauchen weiterhin den Anschluss ihres Besitzers |
| Buch, Entwicklungsbaum, HUD/Scan, Weltkarte | Laufende Facharbeiten; vollständige dynamische Übersetzung noch offen |
| Kreaturen-/Gebäudeeditor, Dorf, D1/D2, Planetenlabor | Vollständige Übersetzung noch offen; API für Fachchats steht bereit |
| Diagnose-/Persistenzfehler | Einzelne Meldungen werden weiterhin vom Bestand auf Deutsch geliefert |

Dies ist **keine vollständig ins Englische übersetzte Spielversion**. Der
Sprachreiter weist auf verbleibende Spieltexte hin. Neue Fachpakete sollen
ihre Texte direkt im gemeinsamen Katalog liefern; der Integrationschat führt
die abgegrenzten Textänderungen zusammen. Die Roadmap bleibt bei ihm.

Weitere Sprache: Sprache und Eigenname in `locales` ergänzen, sämtliche
Übersetzungen eintragen, generieren und im tatsächlichen UI prüfen. Keine
Flaggen als Sprachkennzeichen. Neue Schriften über das gemeinsame Theme
bündeln; CJK/RTL sind ohne Font-, Umbruch-, Layout- und Exportabnahme nicht
als unterstützt auszuweisen. Der gegenwärtige gemeinsame Standardfont bleibt
für Deutsch/Englisch erhalten.

## Prüfung

Godot 4.6.3, isoliertes Benutzerverzeichnis:

```sh
godot --headless --path . --script tests/localization_test.gd
godot --headless --path . --script tests/localization_test.gd -- --localization-read
```

Beide Prozesse müssen dieselben isolierten Benutzerdaten verwenden; niemals
gegen persönliche Spielstände testen. Der zweite Prozess liest die vom ersten
gespeicherte englische Auswahl. Die Testszene kann bei verfügbarer Grafik auch
Menübilder nach `user://localization-*.png` schreiben.

Quellen für den nativen Anschluss:
[Godot 4.6: Internationalisierung](https://docs.godotengine.org/en/4.6/tutorials/i18n/internationalizing_games.html),
[Translation](https://docs.godotengine.org/en/4.6/classes/class_translation.html).
