# INT30-15-SHIPYARD — Fachnachweis vom 30.09.2026

Die separate Werft zeigt übersetzte Moduldetails mit Rolle, X/Y/Z-Maßen,
Drehung und vorhandenen Kennwerten. Fehler nennen betroffene Modulnummern;
die Auswahl springt zum Bauteil und zeigt einen konkreten Korrekturhinweis.
Der Hangarbericht nennt beide Entwürfe mit Revision, ihre Gültigkeit,
Außen-/Innenmaße und den Freiraum beziehungsweise die überschrittenen Achsen
bei 0° und 90°. Die Passentscheidung bleibt bei `Ship.find_hangar_fit`.

## Umfang und Quellstand

- Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`.
- Fachbranch: `agent/int30-15-shipyard-20260930`, Ziel: `agent/integration-pt19-20260930`.
- Produktionsänderung: `05e47b603d167be2294cbcba2a721039d06f9457`.
- Endgültiger Test-/Helferstand: `c028fa3932f69bb4572c4f2a0b0e8555f45cc26e`,
  Tree `561a2c5cfcbe35ef7a6f272566bd1ada85853f56`.
- Lokal geprüfter Code plus vorübergehender Chat-1-Anschluss:
  Tree `ffa794ee58df2377dc4a9d4f1dce90b62a597d9d`.
  [checked-source.json](checked-source.json) enthält die einzelnen SHA256.

Die Prüfungen liefen mit temporärem Katalog-/Registry-Anschluss und generierten
PO-Dateien. Diese vier gemeinsamen Dateien sind im Fachbranch unverändert.
[chat1-shared.patch](chat1-shared.patch) enthält 185 DE/EN-Katalogeinträge und
die einmalige Registrierung des neuen Tests im Vertrag `expedition_design`.
[INTEGRATION.md](INTEGRATION.md) beschreibt die Anwendung durch Chat 1.

Der native Ergebnisbericht nennt noch den vorherigen Commit und einen
schmutzigen Arbeitsstand: Der damals uncommittete Test und Helfer entsprechen
bytegleich `c028fa3`; ihre Hashes sind dokumentiert. Die Produktionsdateien
blieben unverändert. Der anschließende Fachlauf prüfte `c028fa3` mit demselben
Sprach-/Registry-Anschluss und stabiler Quellprovenienz. Spätere Commits fügen
nur diese Nachweise hinzu. Es wird keine Gleichheit des gesamten Liefer-Trees
mit dem temporären Prüf-Tree behauptet.

## Ausgeführte Prüfungen

Engine: **Godot 4.6.3.stable.official.7d41c59c4**, Linux, isolierte Nutzerdaten.
Alle aufgeführten Prozesse endeten erfolgreich; die Runner prüfen zusätzlich
Godot-Fehler und die maschinenlesbaren Testergebnisse.

| Prüfung | Ergebnis | Beleg |
| --- | --- | --- |
| Import, Quellen-/Kunstprüfung und vier Tests im ursprünglichen Projektprofil | bestanden | [headless/results.json](headless/results.json) |
| Endgültiger Stand: `expedition_contract_test`, `fleet_runtime_test`, `shipyard_presentation_test`, `shipyard_test` | alle bestanden; Quelle während des Laufs stabil | [headless-final/results.json](headless-final/results.json) |
| Native Expeditionseingaben | 63 Prüfungen bestanden | [input-expedition.log](native/input-expedition.log) |
| Native Beibooteingaben | 59 Prüfungen bestanden | [input-lander.log](native/input-lander.log) |
| Native Details, Sprache, Fehler, Hangarprüfung | 86 Prüfungen bestanden | [input-presentation.log](native/input-presentation.log) |
| Native Rollen-/Sprach-/Größenmatrix | 48 Prüfungen bestanden | [input-layout.log](native/input-layout.log) |
| Erneutes Öffnen in frischem Engineprozess | 8 Prüfungen bestanden | [restart.log](native/restart.log) |
| Gerenderte Ansichten | 18 Original-PNGs aus der Produktionsszene | [native/results.json](native/results.json) |

Der ursprüngliche Projektlauf prüft den endgültigen neuen Fachtest mit 198
Assertions. Der vorhandene Werfttest und Expeditionsvertrag enthalten auch
ihre bestehenden Neustartfälle. Der letzte Lauf verwendet `--skip-import`,
weil derselbe Ressourcenstand bereits erfolgreich importiert war.

```sh
python3 tools/validate_godot.py --godot GODOT --contracts expedition_design --skip-main --output CHECK_DIR
python3 tools/validate_godot.py --godot GODOT --contracts expedition_design --skip-import --skip-main --output FINAL_DIR
LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2 python3 tools/review_shipyard_presentation.py --godot GODOT --capture --authoring-profile --output RENDER_DIR
```

Der native Lauf nutzt Xvfb mit 1920×1080, `gl_compatibility` und Software-GL.
Im lokalen Runner wurde Xvfb per TCP in demselben Ausführungsprozess gestartet,
weil lokale Unix-X-Sockets dort nicht zugänglich sind. Die exakten Godot-Befehle,
Engine, Log-Hashes und der SHA256 des temporären Projekts stehen im Ergebnis.
Das Werftprofil verwendet die unveränderten Produktionsressourcen mit
LocaleManager und DisplaySettings als Autoloads.

## Geprüfte Bedienung und Bestandsschutz

Für Expedition und Beiboot: Katalogauswahl, Bauvorschau, symmetrisches Anbauen,
Drehung, Entfernen, Undo/Redo einschließlich Tastatur, Positionsänderung,
Speichern, Speichern als Kopie, native Entwurfsauswahl und erneutes Öffnen.
Original und Kopie behalten getrennte Entwurfs- und Modul-IDs. Die gespeicherten
Originalbytes bleiben nach Kopieren und Änderungen an der Kopie gleich.
Abbrechen eines Entwurfswechsels erhält den schmutzigen Entwurf; ein simulierter
Schreibfehler erhält den vorherigen Speicherstand und zeigt einen verständlichen
Fehler. Der frische Prozess überprüft beide Originale und beide Kopien erneut.

DE/EN-Umschalten erhält den Entwurf und die Modulauswahl, übersetzt Filter,
Status, Fehler und fertigen Hangarbericht und baut die Geometrie nicht neu.
Der Bericht wird nach Entwurfsänderungen ungültig gemacht. Sein Ende ist nach
Layoutabschluss im Scrollbereich erreichbar. Geprüft wurden beide Rollen in
beiden Sprachen bei 960×640, 1280×720 und 1920×1080.

## Gerenderte Ansichten

| Zustand | Deutsch | Englisch |
| --- | --- | --- |
| Moduldetails | [DE](native/shipyard-details-de.png) | [EN](native/shipyard-details-en.png) |
| Hangarprüfung | [DE](native/shipyard-fit-de.png) | [EN](native/shipyard-fit-en.png) |
| Expedition 960×640 | [DE](native/shipyard-expedition-de-960x640.png) | [EN](native/shipyard-expedition-en-960x640.png) |
| Expedition 1280×720 | [DE](native/shipyard-expedition-de-1280x720.png) | [EN](native/shipyard-expedition-en-1280x720.png) |
| Expedition 1920×1080 | [DE](native/shipyard-expedition-de-1920x1080.png) | [EN](native/shipyard-expedition-en-1920x1080.png) |
| Beiboot 960×640 | [DE](native/shipyard-lander-de-960x640.png) | [EN](native/shipyard-lander-en-960x640.png) |
| Beiboot 1280×720 | [DE](native/shipyard-lander-de-1280x720.png) | [EN](native/shipyard-lander-en-1280x720.png) |
| Beiboot 1920×1080 | [DE](native/shipyard-lander-de-1920x1080.png) | [EN](native/shipyard-lander-en-1920x1080.png) |

Zusätzlich: [Überlappung](native/shipyard-issue-overlap-en.png) und
[fehlende Energieversorgung](native/shipyard-issue-power-en.png).
Die Detail-, Fehler- und kleinen Layoutansichten wurden visuell geprüft.

## Prüfgrenzen und Integration

Der grafische Start mit sämtlichen ursprünglichen Kampagnen-Autoloads lief lokal
nach 240 Sekunden ins Zeitlimit, bevor die Werftprüfung begann.
[original-native-start-limit/results.json](original-native-start-limit/results.json)
und die zugehörigen Logs dokumentieren diesen erfolglosen Start. Die erfolgreichen
grafischen Nachweise gelten für das ausgewiesene isolierte Werftprofil.

Schiffsformat, DesignStore, Flotteninstanzen, Moduldefinitionen und
Kampagnenfreischaltungen sind unverändert. Die Hangarprüfung beurteilt die
vorhandene mittige geometrische Passung; Einflug, Flugverhalten und Freischaltungen
werden dadurch nicht abgenommen. Ziel-PC-Leistung, Spielschleife und native
Exporte sind ebenfalls keine Aussage dieser Lieferung.

Der konservative Änderungsplan mit gemeinsamem Katalog/Registry verlangt die
volle Integration. Chat 1 muss den gemeinsamen Anschluss übernehmen und den
neuen Integrations-Tree mit voller Suite und den vier Pflicht-Gates prüfen.
Dieser Fachnachweis und der Draft-PR erteilen keine Merge-Freigabe.
