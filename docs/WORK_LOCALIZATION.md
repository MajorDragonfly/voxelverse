# Übergabe L1 – Sprachverwaltung

Auftrag: Voxelverse in verschiedenen Sprachen spielen können. Eigener Branch
`agent/localization`, Ausgangsbasis `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
Keine fremden Fachbranches übernommen, kein Merge nach main, keine Änderung
an ROADMAP.md. Der technische Anschluss ist in [LOCALIZATION.md](LOCALIZATION.md)
beschrieben.

## Lieferung

- Zentraler Sprachdienst auf Godots TranslationServer, Deutsch/Englisch,
  regionale Systemsprachen und deutscher Rückfall.
- 221 gemeinsame Textvorlagen, einschließlich einer pluralisierten Vorlage;
  Generator und Validierung für UTF-8-Quelle, Platzhalter und Kataloge.
- Sprachreiter im vorhandenen F8-Menü, Übernehmen/Speichern und Verwerfen;
  kein Neustart nötig und keine neue Pauseverwaltung.
- Geräteweite atomare Sprachpräferenz, Schutz unbekannter Dateiversionen.
- Vorhandene Menütexte über native automatische Übersetzung; gezielte
  Anschlüsse für dynamische Steuerung, Einführung und Speicheransichten.
- Keine Änderung an Kampagnenschema, bestehenden Saves, Arten oder Namen.

## Gemeinsame Einbaupunkte

| Datei | Änderung / Integrationshinweis |
| --- | --- |
| `project.godot` | `LocaleManager` vor vorhandene Autoloads setzen; `locale/fallback="de"` |
| `core/display_settings.gd` | Eigenen Sprachreiter hinzufügen; vorhandene Übernehmen-/Öffnen-/Schließenpfade erweitern |
| `core/input_preferences.gd` | Nur sichtbare Tastenbezeichnungen und formatierte Konfliktmeldungen übersetzen |
| `autoload/session_flow.gd` | Dynamische Hilfe übersetzen/aktualisieren; Abenteuername vor automatischer Übersetzung schützen |
| `ui/frontend/main_menu.gd` | Hilfe/Datum aktualisieren; eigene Namens-/Seed-Eingabe beim Wechsel erhalten |
| `ui/frontend/controls_settings.gd` | Bindungstexte und Tastennamen aktualisieren; Entwürfe erhalten |
| `ui/frontend/save_browser.gd` | Zeit/Phasen/Anzahlen, eigene Namen, Auswahl/Umbenennung erhalten |
| `ui/frontend/first_steps.gd` | Dynamische Vorlagen vor Formatierung übersetzen |

Eigene neue Dateien: `core/localization/`, `ui/localization/`, `localization/`,
`tools/localization/catalog.py`, `tests/localization_test.gd` und diese beiden
Dokumente. Native UID-/PO-Importbegleiter der neuen Dateien gehören dazu.
Die laufenden Änderungen an Buch, HUD, Editor, Stamm und Planeten wurden nicht
verändert. Menüanschlüsse sind bei späterer Übernahme mit Auftrag 7/UI
abzugleichen; keine neueren Branch-Köpfe ohne Abschlussbeleg integrieren.

## Nachweise

Lokal unter Linux mit Godot 4.6.3:

- Sauberer Editorimport ohne Scriptfehler.
- Katalogprüfung: 221 Einträge / 2 Sprachen, keine fehlenden Werte oder
  abweichenden Platzhalter.
- 39 gezielte Prüfungen: Systemvarianten, Rückfall, Singular/Plural, Zahlen,
  unveränderte Datenwerte, fehlgeschlagenes Speichern, zukünftiges Schema,
  Sprachwechsel im pausierten Menü, native Label-/Layoutaktualisierung,
  eingegebener Name/Seed, verworfene Auswahl, unfertige Umbenennung und
  byteidentischer echter Spielstand.
- Zweiter Godot-Prozess: gespeichertes Englisch und Katalog beim Start,
  2 zusätzliche Prüfungen bestanden.
- Bestehende Tests `input_preferences_test`, `onboarding_test`,
  `save_slots_test`, `menu_input_test` bestanden. Der Menütest enthält echte
  GUI-Ereignisse, Pause-/Mauswiederherstellung und den bisherigen Laborweg.
- PCK mit vorhandenem Linux-Preset erzeugt; Start außerhalb des Quellprojekts
  aus diesem Paket prüft gespeichertes Englisch und den eingebetteten Katalog.
- `git diff --check` bestanden.

Grafiksitzung konnte in dieser Umgebung wegen nicht verfügbarer X-Sockets
nicht starten. Deshalb keine visuelle oder Windows-Abnahme behauptet. Der
Godot-Test deckt die native Text-/Layoutaktualisierung auch headless ab.

## Grenzen und Folgearbeit

L1 ist eine funktionsfähige Sprachverwaltung mit angeschlossenen Menüs,
keine vollständig englische Übersetzung sämtlicher Spielinhalte. Vollständige
Texte für Buch, Entwicklung, HUD/Scan/Karte, Editoren, Dorf, D1/D2 und Labore
folgen bei ihren Besitzern. Einige bestehende Fehlertexte und bereits offene
Hilfeseiten können bis zum erneuten Öffnen noch ihren bisherigen Text zeigen.
Keine Sprachaufnahmen, keine CJK-/RTL-Schriftfreigabe, kein neuer Windows-
Gesamtexport. Diese Grenzen stehen auch im sichtbaren Sprachhinweis.

Weitere Sprachen mit mehr/anderen Pluralformen sowie anderen Zahlen-/Datums-
oder Schriftsystemen brauchen passende Erweiterungen und konkrete Abnahme.
Die beiden aktuellen Sprachen verwenden dieselben bestehenden UI-Bausteine.

## Exakter geprüfter Implementierungsstand

Codecommit: `23da78e028182fb2c4c70210ac4d35a52a678f6e`.
Dateibaum: `9b6e075ceac4afb68dc5e420d9d653606ece500f`.
Ein nachfolgender Commit ergänzt ausschließlich diese Übergabekennung.
Zur Übernahme dieses abgeschlossene Paket verwenden; Folgearbeiten auf dem
Branch sind damit nicht automatisch freigegeben.
