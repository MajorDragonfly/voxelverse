# ARCH-14: Große Sammlungen im Entdeckungsbuch

Stand: 15. September 2026. Fachbranch `agent/arch14-journal-paging-2026-09-15`,
Basis `main` / `bb2f83b56267964baa7037720c4daca26fe3d007`.
Dieses Teilpaket ist zur Integration vorbereitet; ARCH-14 bleibt insgesamt offen.
Das vorherige Population-/Nahrungspaket in [PR #79](https://github.com/MajorDragonfly/voxelverse/pull/79)
ist unabhängig davon.

## Problem und Ergebnis

Das Entdeckungsbuch zeigte bereits höchstens 100 Einträge pro Seite. Beim Öffnen
kopierte es dennoch den gesamten `ProgressionService.export_state()`, einschließlich
aller gespeicherten Körperansichten, Tierbegegnungen, Stammes- und Verhaltensdaten.
Jeder Seitenwechsel erstellte und sortierte wieder die vollständige Artenliste;
der Tierrollenfilter dekodierte dabei sämtliche gespeicherten Körperansichten.

Der neue `core/discovery/journal_catalog.gd` liest einmal kompakte Suchmetadaten.
Arten- und Regionsreiter erhalten daraus höchstens 100 Zeilen. Die Trefferliste
enthält nur IDs und wird bis zur Änderung von Suche, Filter, Rollenbezeichnungen
oder Metadaten wiederverwendet. Körperdaten werden erst für die ausgewählte Art
und die nacheinander gerenderten Miniaturen gelesen. Es gibt keine neue Grenze
für die Anzahl gespeicherter Entdeckungen.

Namen, natürliche Sortierung mit stabiler ID bei gleichen Artnamen, Fundorte,
Lebensweisen, gültige gescannte D1-Tierrollen, Teileherkunft, Forschungsziele und
Artenvergleich bleiben erhalten. Die vorhandene D1-Prüfung erhält zum Filtern
nur den Eignungsdatensatz; sie generiert keine Rollen aus einer ungescannten Art.
Alte Beobachtungen ohne Vorschau bleiben weiterhin sichtbar.

## Besitzer, Lebenszyklus und Budgets

| Bereich | Vertrag |
| --- | --- |
| Persistenz | `ProgressionService` bleibt alleiniger Besitzer der Entdeckungen; unverändertes Saveformat und vollständige Speicherung. |
| Index | O(N) kleine Metadatensätze für Arten/Regionen; kein Körper-/Anhangsarchiv und keine Begegnungs-, Stammes- oder Verhaltenskopie. |
| Treffer | O(N) IDs für die aktive Abfrage; erneutes Filtern/Sortieren nur bei geänderter Abfrage oder neu gebundenem Zustand. |
| Aktive Seite | Höchstens 100 Metadatenzeilen und 100 Listeneinträge. |
| Details | Gezielte Kopie einer Beobachtung pro Leseaufruf; keine Referenz, über die der Leser das Original verändern kann. |
| Vorschauen | Vorhandene Einzel-/Vergleichsvorschauen; ein Miniaturmodell wird nach dem anderen aufgebaut. Texturcache weiterhin höchstens 192 Bilder. |
| Schließen | Metadaten, aktive Seite, Vorschauwarteschlange und Texturcache werden freigegeben. |

Neue Entdeckungen und Laden/Zurücksetzen bauen den Index über die vorhandenen
Signale neu auf. Wandert die ausgewählte Art dadurch über eine Seitengrenze,
folgt das Buch ihrer ID. Ein Seiten-/Reiterwechsel oder Schließen entwertet
laufende Miniaturaufträge, sodass verspätete Bilder nicht in die neue Ansicht
gelangen. Nicht mehr benötigte Teileaufträge einer vorherigen Artauswahl werden
aus der Warteschlange entfernt.

Die Gesamtentdeckungen liegen beim Datenbesitzer weiterhin vollständig im RAM und
im zentralen Fortschrittssnapshot. Dieses Paket reduziert die zusätzliche Arbeit
des Buchs; es ist keine Auslagerung des Entdeckungsarchivs auf Regionsdateien.
Der einmalige Indexaufbau und eine neue Suchabfrage skalieren weiterhin mit N.
Die Mengenbudgets sind keine garantierte Framezeit auf dem Ziel-PC.

## Prüfung

Godot `4.6.3.stable.official.7d41c59c4`, isolierte Nutzerdaten, strikte Prüfung auf
Skript-/Enginefehler und geleakte Objekte. Maschinenlesbare Ergebnisse und
SHA-256 der geprüften Quelldateien: [journal-paging-results.json](evidence/arch14/journal-paging-results.json).

- `journal_paging_test`: 10.005 Arten und 10.005 Regionen; alle 101 Artenseiten
  vollständig und ohne doppelte IDs, Suchtreffer am Ende der Sammlung,
  Lebensweisen-/Tierrollenfilter, geänderte Rollenbezeichnungen, Regionssortierung,
  Teilseite/Leeransicht, unveränderliche Metadaten- und Detailkopien sowie alte und
  unbekannte Datenrevisionen. Der Test prüft ausdrücklich, dass Index und Blättern
  keine vollständigen Beobachtungen laden.
- Derselbe Test bedient das echte Buch mit jeweils 1.205 gespeicherten Arten und
  Regionen: nächste/letzte Seite, Vorschau der letzten Art, Suche, Reiterwechsel,
  Schließen, Auswahl über eine nachträglich verschobene Seitengrenze, Zurücksetzen
  und Laden bei geöffnetem Buch. Ein unabhängiger Godot-Prozess lädt den echten
  Kampagnenspielstand und öffnet die letzte Seite mit rekonstruierter Körperansicht.
  Blättern verändert weder Fortschrittsdaten noch die gespeicherte Datei.
- Bestehende Regressionen: `discovery_journal_test`, `domestic_fauna_journal_test`,
  `species_comparison_test`, `owned_animal_localization_test`, `research_goals_test`.
  Import, Quellenverträge und Art-Quellenprüfung bestehen ebenfalls.

Die Prüfungen laufen headless und bauen reale Buch-/Modellknoten auf. Eine neue
grafische Abnahme einschließlich des asynchronen Bildlesens steht aus:
der verfügbare Ausführungskontext verweigert die für Xvfb nötigen Unix-Sockets.
`journal_paging_test -- --paging-capture` bietet auf einem grafischen Godot-Lauf
Screenshots der letzten Arten- und Regionsseite. Es wird kein neuer FPS- oder
Zielhardware-Nachweis behauptet.

Reproduktion:

```sh
python tools/validate_godot.py --godot /path/to/godot-4.6.3 --skip-main --tests journal_paging_test discovery_journal_test domestic_fauna_journal_test species_comparison_test owned_animal_localization_test research_goals_test
```

## Integration und verbleibendes ARCH-14

Das Paket ändert den Arten-/Regionsleser in `discovery_journal.gd`, fügt den
Katalog und einen registrierten Test hinzu. Es ändert weder `ProgressionService`
noch `SaveGameService`, D1/D2-Verträge, Fähigkeitenansicht oder Übersetzungskataloge.
Beim Zusammenführen von `tools/validation/contracts.json` die Testnamen anderer
Fachbranches erhalten; `journal_paging_test` gehört einmal zu `discovery_map`.

Das laufende ARCH-25-Fähigkeitenpaket und das Population-Paket #79 sind keine
Codeabhängigkeiten. Dokumentationsänderungen anderer ARCH-14-Lieferungen erhalten.
Vollständig segmentierte Entdeckungs-/Begegnungsarchive, die noch vorhandene
Labor-Populationsgrenze und die gemeinsame Langzeit-/Ziel-PC-Abnahme bleiben eigene
Folgeschritte; daraus folgt kein Abschluss des gesamten ARCH-14.
