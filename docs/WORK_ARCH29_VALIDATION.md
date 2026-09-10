# ARCH-29 – gemeinsame Vertragsprüfung

Stand: 10. September 2026. Auftrag: **ARCH-29 / M0/M10**, abgegrenzte Lieferung der Testzuordnung und des Sprachkatalog-Gates. Basis: veröffentlichter `main` **`ea900f2e09946660694a9e59399b4680a5655a85`** (PR #48). Branch: `agent/arch29-contract-validation-2026-09-10`.

ARCH-02, ARCH-05, ARCH-20, ARCH-23 und ARCH-25 sind laut Lars parallel vergeben. Zusätzlich läuft die HUD-/Journal-Arbeit. Dieses Paket ändert ausschließlich Prüfwerkzeuge, die gemeinsame Godot-CI und diesen eigenen Übergabebericht. Keine Änderungen an Spielcode, Speicherformaten, Übersetzungen, gemeinsamen Fachkatalogen oder Roadmap. Fremde unfertige Checkouts/Branches wurden nicht übernommen.

## Anschluss und Datenbesitzer

`tools/validation/contracts.json`, Schema 1, ordnet jeden vorhandenen `tests/**/*_test.gd` genau einem primären Fachvertrag zu. Die Zuordnung besitzt **keinen Spielzustand**. Gemeinsame Abnahmeszenarien können Tests aus mehreren Fachverträgen nennen. Die automatische Dateisuche bleibt für Auswahl und vier disjunkte CI-Shards zuständig; das Register darf keine existierenden Tests aus der Ausführung ausblenden.

| Vertrag | Bereich | Tests auf der Basis |
|---|---|---:|
| `campaign` | Kampagne, Körperidentität und Speichern | 10 |
| `spherical_gameplay` | Gemeinsame Kugel-Spielschleife | 2 |
| `regions_simulation` | Regionsspeicher, Fernarbeit und Budgets | 4 |
| `surface` | Planeten, Oberflächenadapter und Streaming | 17 |
| `terrain_art` | Gelände, Vegetation, Wasser und Assetanschluss | 14 |
| `creature_body` | Kreaturenentwurf, Körperanschlüsse und Animation | 11 |
| `blueprints` | Gemeinsame Baupläne und Designregister | 1 |
| `domestic_fauna` | Pflichtarten, Körperrollen und Vorkommen | 7 |
| `domestication` | Individueller Tierbesitz und Zähmung | 6 |
| `wildlife` | Wildtierverhalten, Sammeln und Trinken | 7 |
| `home_progression` | Heimat, eigene Spezies und Fortschritt | 10 |
| `village` | Dorf, Versorgung, Wachstum und Milchfracht | 10 |
| `neighbors` | Nachbarstämme und Hilfe | 3 |
| `discovery_map` | Scanner, gemeinsame Bücher und Karten | 10 |
| `frontend_locale` | Menüs, Eingaben und Sprachwechsel | 6 |
| `audio` | Audioereignisse, Mischung und Lebenszyklus | 9 |

Alle 127 vorhandenen Godot-Tests sind registriert. Neue Tests benötigen in demselben Fach-PR einen Eintrag im passenden Vertrag; ein neues Fachmodul bekommt bei Bedarf eine eigene Gruppe. Entfernte oder umbenannte Tests müssen auch im Register angepasst werden. Unregistrierte, fehlende oder doppelt zugeordnete Tests und ungültige Szenarioreferenzen brechen die Prüfung mit dem konkreten Namen ab. Testnamen sind portable relative Pfade ohne `.gd`, etwa `audio/interface_audio_test`.

Der vorhandene `tools/localization/catalog.py --check` bleibt der einzige Übersetzungsgenerator und -validator. Das neue Gate führt ihn **lesend** aus und prüft Katalogschema, eindeutige Schlüssel, DE/EN-Vollständigkeit innerhalb des Katalogs, Platzhalter sowie die drei generierten Ressourcen `de.po`, `en.po` und `catalogs.gd`. Eine bestandene Prüfung bedeutet keine Vollübersetzung sämtlicher Bildschirme.

## Ausführung und Ergebnisse

```bash
# Schnellprüfung ohne Engine; optional maschinenlesbarer Bericht:
python3 tools/check_validation_contracts.py --output /tmp/voxelverse-contracts.json

# Fehlerpfade der Werkzeuge, einschließlich realem Kataloggenerator:
python3 -m unittest discover -s tests/tooling -p '*_test.py'

# Gezielte bestehende Runtime-Verträge mit Godot 4.6.3:
python3 tools/validate_godot.py --godot /pfad/zu/godot --skip-main \
  --tests body_identity_test region_store_test far_simulation_test localization_test \
  --output /tmp/voxelverse-arch29
```

Der gemeinsame Runner prüft die Verträge **auch bei `--skip-import` und explizit leerem `--tests`**. Ein Fehler stoppt vor Import/Spielstart. Unbekannte angeforderte Tests werden ausdrücklich abgelehnt. Bestehende Zeitlimits, Save-Isolation, strenge Engine-Logprüfung und tatsächliche Laufzeiteinstiege bleiben bestehen.

In `.github/workflows/godot-validate.yml` läuft der neue `contracts`-Job vor den vier Godot-Shards und dem Runtime-Job. Der bestehende abschließende Job `validate` verlangt den Erfolg aller drei Bereiche. Fehlende/abgebrochene Voraussetzungen können dadurch keinen grünen Abschluss erzeugen. Native Export-, Grafik- und Leistungsworkflows bleiben separate Nachweise.

`contracts.json` im Ergebnisordner enthält die Zuordnungssummen, die Szenarien mit Grenzen und den Quellcommit. `results.json` ergänzt Quellcommit, Status der **getrackten** Arbeitskopie, ausgewählte Route, Prüfart und primären Fachvertrag je Godot-Test. Nicht getrackte Dateien werden durch dieses Git-Merkmal nicht beschrieben; freigegebene Nachweise deshalb aus einem vollständig committed Fachstand erstellen. Neue Felder sind additiv; `godot`, `checks`, `name`, `passed`, `exit_code` und `seconds` bleiben bestehen.

| Nachweisart | Aussage | Keine Aussage über |
|---|---|---|
| `source_contract` | Register, Katalog und generierte Quellen konsistent | Godot-Spielbarkeit |
| `editor_import` | Tatsächlicher Editorimport ohne erfasste Enginefehler | Spielkette, Darstellung oder FPS |
| `headless_godot` | Testcode wurde wirklich in Godot ausgeführt; Umfang steht im Fachtest | Native EXE/PCK, sichtbare Grafik oder Ziel-PC-Leistung |
| Native Pakete | Bestehender Exportworkflow mit wirklichen Linux-/Windows-Paketen | Vollständige manuelle Abnahme |
| Grafik/Ziel-PC | Nur tatsächliche Render-/Spiel-/Messroute mit Hardware und Preset | Darf nicht aus Headless-Erfolg abgeleitet werden |

Viele ältere Weltprüfstände verwenden weiterhin die Diagnose-Flachwelt. Ihre Einordnung in einen Fachvertrag macht sie nicht zu einer Kugelwelt-Abnahme. Für die gemeinsame Kugelkette sind insbesondere `spherical_creature_test`, `spherical_gameplay_test` und `body_travel_test` maßgeblich.

## Relevante Architekturgrenzen

Die Szenariostatus in der Registrierung heißen `implemented`, `partial` und `pending`: Sie beschreiben vorhandenen Prüfcode, **keinen aktuellen Testerfolg**. Der schnelle Quellencheck führt diese Szenarien nicht aus.

| Szenario | Bereits vorhandener Nachweis | Verbleibende Grenze |
|---|---|---|
| Gleicher Seed in verschiedenen Systemen | `body_identity_test`, `body_travel_test`: getrennte Daten, A–B–A, Altformat und Neustart | Native-/Ziel-PC-Nachweis separat |
| Mehr als 96 Regionen | `region_store_test`: 1.200 Store-Einträge, Eviction, alte Wurzel und neuer Leser | Kein vollständiger entwickelter Kampagnensnapshot/Prozessneustart; ARCH-13/14 bleiben offen |
| Mehr als 256 Tieridentitäten | Noch kein ausreichender Größenprobe registriert | Mit ARCH-14 implementieren |
| Zukünftige Bauplanversion | Noch kein entsprechender Nachweis auf der Basis | Gehört zum parallel vergebenen ARCH-23; nach dessen Integration exakt zuordnen |
| Nah-/Fernfracht | `far_simulation_test`, `body_travel_test`, `spherical_gameplay_test` | Fernmilch hat D2-Leseport-Prüfstand; echtes gebundenes Tier in A–B–A und lange Abwesenheiten separat |

Damit sind die ersten beiden ARCH-29-Teilpunkte geliefert. Neue Größen-/Bauplanfälle bleiben bei ihren Implementierungsbesitzern; ARCH-29 ist eine fortlaufende Integrationsaufgabe und wird nicht pauschal abgeschlossen.

## Übergabe an parallel laufende Pakete

- ARCH-02: Fachmessungen bleiben in dessen Leistungswerkzeugen. Neue `*_test.gd` im passenden Vertrag ergänzen; keine Headless-Zeiten in Ziel-PC-FPS umdeuten.
- ARCH-05/20/23/25: neue Godot-Tests bei Integration in `contracts.json` eintragen. Bei ARCH-23 außerdem `future_blueprints` mit den tatsächlich gelieferten Tests und konkreten Grenzen aktualisieren.
- ARCH-25/HUD: Sprachkatalog-Änderungen weiterhin über den bestehenden Generator erzeugen; das Gate verändert die Dateien nicht automatisch.
- Integration übernimmt nur den konkreten abgeschlossenen Commit dieses Branches und führt die gemeinsame CI erneut aus. Der Branch wurde nicht nach `main` gemergt.

## Lokale Validierung

Wird nach Abschluss der gezielten Ausführung mit dem exakten Implementierungscommit ergänzt. Keine neue Grafik- oder FPS-Abnahme Teil dieses Pakets.
