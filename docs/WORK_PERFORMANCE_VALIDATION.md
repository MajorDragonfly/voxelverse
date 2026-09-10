# Leistungsprüfung und CI – 9. September 2026

**Aktueller Anschluss (10. September):** Neue Messläufe verwenden Protokoll 2 für die Kugelkampagne; siehe [WORK_ARCH02_PERFORMANCE.md](WORK_ARCH02_PERFORMANCE.md). Der folgende Bericht dokumentiert die historische Flachwelt-Messung.

## Paket und Integrationsfolge

Branch: `agent/performance-validation-2026-09-09`.
Basis ist unser abgeschlossenes Bereinigungspaket **PR #34**, Commit
`714a96b50bc89f84bb348d52121e0a302193ab39`. Dieser Folge-PR richtet sich zunächst
an dessen Branch; nach Übernahme von #34 kann er gegen main umgestellt werden.
Keine fremden unfertigen Pakete übernommen, kein automatischer Merge.
Der veröffentlichte Commit und der lokal geprüfte Quellbaum stehen im PR-Text.

Die zuletzt veröffentlichten Fachstände für Körperanschlüsse, Körperpassung,
D1/D2, M1d, Auftrag 7, Dorfwirtschaft und Stammesfortschritt wurden geprüft.
Keine Dateikollisionen; genaue Commits in `validation/performance-tooling/branch-checks.json`.
Nicht veröffentlichte Arbeit ist nicht sichtbar. Die Änderung betrifft
Prüfwerkzeuge, deren CI und diese Übergabe; keine produktive Spielmechanik,
Speichermigration, Roadmap oder UI-Gestaltung.

## Neue reproduzierbare Leistungsprobe

`tools/profile_performance.py` startet `tools/performance_route_probe.gd` mit
isolierten Benutzerdaten und einem neuen externen Ausgabeordner. Eine portable
Engine wird wie beim Quelltest in einer temporären Laufkopie ausgeführt.

Der Ablauf benutzt das echte Startmenü und die vorhandenen SessionFlow-Funktionen:
Neues Spiel → geladene Welt → feste Strecke nach Osten → Rückkehr → speichern
und Hauptmenü → denselben Spielstand erneut laden. Drei Durchläufe sind Standard.

- Fester Seed, 192 m je Richtung, 1 m je Prozessframe, Frame-Limit 60.
- Der Startchunk muss am Wendepunkt entladen und nach der Rückkehr wieder vorhanden
  sein. Die gespeicherte Startposition wird bei erneutem Laden geprüft.
- Gemessen werden Szenen-/Streamingdauer, Median/P95/P99/Maximum der Frame-Abstände,
  maximale wartende Chunkzahl, statischer Speicher sowie Knoten/Ressourcen/Waisen.
- Frame-Abstände werden zwischen aufeinanderfolgenden Frame-Ereignissen gemessen;
  dadurch zählt auch die Arbeit des Prüfskripts zwischen den Ereignissen mit.
- Weltszenen werden über schwache Referenzen geprüft. Im Menü dürfen keine alten
  Weltszenen oder WorldManager zurückbleiben.
- Grafische Läufe können zusätzlich echte Draw Calls erfassen. Fehlende Draw Calls
  bei angeforderter Grafik gelten als Fehler. Headless erfindet keine GPU-Werte.
- CPU-/Physikwerte aus Godots Performance-Monitor sind langsam aktualisierte
  Messanzeigen, keine unabhängigen Einzelbildzeiten und keine Summanden der Framezeit.
- Speicheränderungen nach dem ersten warmen Besuch werden ausgewiesen, nicht pauschal
  als Speicherleck gewertet: Caches und der wachsende Prüfbericht benötigen selbst Speicher.

Die Strecke setzt den vorhandenen Spieler kontrolliert entlang der Geländeoberfläche.
Das ist ein Streaming-Belastungstest mit deaktivierter Spielerphysik und unterdrücktem
Wildtierschaden innerhalb dieser isolierten Prüfsitzung. Es ist keine Abnahme der
Laufsteuerung, Wegfindung oder Kollision. Die produktiven Dateien werden nicht verändert.

### Start unter Windows

Aus dem Projektverzeichnis, Python 3.11 oder neuer installiert:

```powershell
python tools/install_godot.py --directory ../godot-toolchain --editor-only
python tools/profile_performance.py --godot ../godot-toolchain/editor/Godot_v4.6.3-stable_win64_console.exe --output ../performance-berichte/lauf-01
```

Für einen grafischen Lauf einen **neuen** Ausgabeordner verwenden:

```powershell
python tools/profile_performance.py --godot ../godot-toolchain/editor/Godot_v4.6.3-stable_win64_console.exe --renderer gl_compatibility --output ../performance-berichte/grafik-01
```

Unter Linux heißt die installierte Engine `Godot_v4.6.3-stable_linux.x86_64`.
`--help` zeigt Seed, Zyklen, Distanz, Schrittweite, Frame-Limit und Auflösung.
Ohne `--output` entsteht ein eindeutiger temporärer Berichtsordner, dessen Pfad
angezeigt wird. Bestehende Ergebnisse werden nicht überschrieben. Die Engine schreibt
laufend `engine.log`; am Ende entstehen `capture.json` und `performance.json`.

## Ergebnis des lokalen Abschlusslaufs

Godot 4.6.3, Linux, headless; drei Besuche / insgesamt **1.152 m**. Alle zwölf
Messabschnitte erfolgreich, Startchunk in jedem Durchlauf entladen und wieder geladen.
Diese Werte stammen vom geteilten Entwicklungsrechner, nicht von Lars’ PC.
Frame-Limit, Prüfskript und andere Prozesse beeinflussen die Zeiten.

| Abschnitt | Dauer je Durchlauf (s) | P95 Frame-Abstand (ms) |
|---|---:|---:|
| world_ready | 14.85–15.44 | 29.71–38.26 |
| outward | 14.93–16.45 | 22.30–32.38 |
| return | 13.60–15.32 | 27.79–32.49 |
| menu_return | 1.06–1.10 | 16.83–16.96 |

Nach jedem Menüwechsel: **219 Knoten, 541 Ressourcen,
0 Waisenknoten, keine alten Weltszenen und keine aktiven WorldManager**.
Diese Zähler blieben über alle drei Rückkehrpunkte gleich. Der gemeldete statische
Speicher änderte sich vom ersten warmen Menü zum dritten um **44.188 Bytes**.
Das ist ein begrenzter Messbefund, kein allgemeiner Beweis für Leckfreiheit.

## Testausgaben vom Quellcode getrennt

Der vorhandene `benchmark_streaming.gd` schreibt nicht mehr fest nach
`art/review/benchmark_v2/streaming_cpu_measurements.json`.
`validate_godot.py` übergibt stattdessen seinen jeweiligen Ergebnisordner über
`--report`. Direkt gestartet liegt der Standardbericht unter `user://`.
Relative Pfade, `res://` und absolute Pfade innerhalb des Projektordners werden
abgewiesen. Fehler beim Schreiben führen zu einem fehlgeschlagenen Prüflauf.

Prüfnachweis: sechs Chunks gemessen, externer JSON-Bericht erzeugt, beide Varianten
für einen Schreibversuch ins Projekt abgewiesen; SHA-256 der historischen
versionierten Messdatei unverändert. Modell- und Audioexporter behalten
ihre absichtlichen Quellausgaben; diese sind keine Testlogs.

`profile_environment.py` verwendet jetzt ebenfalls die gemeinsame Isolation für
portable Engines. Die vorhandenen visuellen Prüffälle und Renderer bleiben erhalten.

## Weniger Aufwand in der CI

Die drei allgemeinen Workflows `godot-validate`, `modular-assembly-validate` und
`planet-diversity-v9` verwenden eine gemeinsame lokale Setup-Action:

- Nur das Godot-Editorarchiv wird gecacht; keine Spielstände, Importdaten oder
  Exportvorlagen werden zwischen Jobs geteilt.
- Der bestehende SHA-256-Prüfpfad des Installers bleibt bei jedem Aufruf aktiv.
- Neues `--editor-only` spart in diesen Prüfabläufen den Vorlagen-Download.
  Der Installer ohne diesen Schalter liefert weiterhin sämtliche bisherigen
  Windows-/Linux-Exportvorlagen; drei Regressionstests sichern beide Modi ab.
- Überholte Läufe werden nur innerhalb desselben Workflows, Ereignistyps und
  Git-Refs abgebrochen. Andere Fachbranches oder ihre PR-Prüfungen bleiben getrennt.

Branch-Push und Pull Request prüfen unterschiedliche Git-Stände: Branchkopf bzw.
synthetischen Merge. Ihre Trigger und alle bisherigen Abnahmekommandos bleiben
vollständig erhalten. Sie wurden deshalb nicht pauschal zu einer einzigen Prüfung
zusammengelegt. Grundlage: [GitHub-Ereignisse](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#pull_request),
[Concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
und [Cache-Verhalten](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching).

Der neue Workflow `performance-profile.yml` führt die Headless-Strecke bei Änderungen
an diesen Prüfwerkzeugen aus und bietet einen manuellen Start. Es ist ein Diagnose-
workflow mit siebentägigen Ergebnisartefakten, keine neue Grafik-/FPS-Freigabe.

## Verifikation und Grenzen

- Projektimport und Modellquellen-Roundtrip erfolgreich.
- Abschließender echter Headless-Lauf mit drei Weltbesuchen, Save/Load und zwölf Messabschnitten erfolgreich.
- Sechs bestehende Streaming-CPU-Proben und der Schutz der bisherigen Messdatei erfolgreich.
- Fünf Python-Regressionstests erfolgreich: Editor-/Exportinstallation und Schutz von
  Quellordnern sowie vorhandenen Messberichten.
- Echter Godot-Editor zweimal aus vorhandenem geprüftem Archiv installiert, ohne
  erneuten Download oder Exportvorlagen; Engine-Version danach korrekt.
- Actionlint 1.7.12: vier Workflows fehlerfrei. Composite-Action und Python-Quellen geprüft.
- Trigger und Abnahmekommandos der drei optimierten Workflows mit dem Ausgangsstand
  verglichen: erhalten. `git diff --check` erfolgreich.

Nachweise: `validation/performance-tooling/`. Kein neuer Windows-Gesamtexport,
keine lokal ausgeführte grafische Streckenprüfung und keine FPS-Zusage.
Der aktuelle Prüfablauf betrifft die bestehende Ebenenkampagne; M1d und spätere
Epochen benötigen eigene Messprofile auf ihren fertig integrierten Spielabläufen.
