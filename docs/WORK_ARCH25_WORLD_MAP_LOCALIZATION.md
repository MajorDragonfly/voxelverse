# ARCH-25 — Teilpaket 2: Weltkarte DE/EN

Stand: 2026-09-10. Basis: `ea900f2e09946660694a9e59399b4680a5655a85`.
Eigenständiges Teilpaket nach der Nachbarstamm-Lokalisierung in PR #51.
ARCH-25 insgesamt bleibt offen; dieses Paket umfasst die Weltkarte.

## Ergebnis

- Titel, Aktionen, Filter, Legende, Hinweise, Fehler und Maßstab sind auf Deutsch und Englisch verfügbar. Kilometer verwenden den Dezimaltrenner der Sprache; Kugelkarten behalten die Kennzeichnung als Äquatorbreite.
- Ein Sprachwechsel aktualisiert die vorhandenen Ortsbuttons und die gezeichneten Beschriftungen. Kartenausschnitt, Zoom, Auswahl, Filter, Tastaturfokus, Listenposition und Kartenpause bleiben erhalten. Der Sprachwechsel fordert keine neuen Geländesamples an.
- Standardnamen eigener Nester, der Speziesheimat und bekannter Freundeslebensräume werden ausschließlich für die Anzeige übersetzt. Die Kombination aus reservierter Anbieterkennung und bekanntem Namenstemplate unterscheidet sie von freien Namen. Ein Name wie `Weltkarte {name}` bleibt wörtlich erhalten.
- Bei schmaler Anzeige und großer Schrift erhält die Ortsliste genügend Platz für eine vollständige Aktionszeile. Maßstab und Ortsdetail erscheinen wieder beim Wechsel zurück zur Karte. Der Detailtext ist außerdem als Tooltip verfügbar.

## Datenverantwortung und Kompatibilität

`exploration_tracker.gd` liest weiterhin die bestehenden Kampagnen-/Labor-Kartendaten und bekannten Freundschaften. `exploration_atlas`, Kartenformat 1, Ortskennungen, gespeicherte Namen, Erkundungszellen und Fortschritt behalten ihren bisherigen Vertrag. Die Präsentationshilfe und die Anzeige-Kopien schreiben diese Daten nicht um. Es gibt keine Migration und keinen neuen persistenten Cache.

Der Tracker liefert zusätzlich den flüchtigen `problem_code` für volle Sammlungen, ungültige Datensätze und unpassende Oberflächen. Ausführliche Diagnosemeldungen bleiben in `problem` erhalten. Beide Werte werden vor einem neuen Erkundungsversuch zurückgesetzt, damit nach erfolgreicher Wiederherstellung kein alter Fehler angezeigt wird. Unbekannte Kartenversionen werden weiterhin abgelehnt und erhalten.

## Prüfung

Godot 4.6.3, isolierte Spielstände und Einstellungen:

- `world_map_localization_test.gd` erweitert den echten Spieler-/Karten-/Speicher-/Neustartpfad aus `world_map_test.gd`. Er prüft wiederholte DE/EN-Wechsel, dieselben Controls und Kartenobjekte, unveränderte Kampagnen-/Fortschrittsdaten und identische gespeicherte Dateiinhalte. Eine lange Ortsliste prüft Fokus und Scrollposition; unbekannte Lebensräume bleiben verborgen. Fehlercode und erfolgreiche Erholung werden über den echten Tracker geprüft.
- Der bestehende `world_map_test` und `living_planet_map_test` bestanden, einschließlich frischem Engine-Prozess und Schutz zukünftiger Kartenversionen. Zusätzlich wurden die gemeinsame Lokalisierung und Minikarte geprüft.
- Native OpenGL-Aufnahmen entstanden bei 1920×1080, 1280×720 und 800×600, jeweils mit 100/150 % UI-Skalierung und DE/EN. Zusammen mit Ortsliste und Leerzustand sind dies 16 Aufnahmen. Die Bedienelemente wurden auf Erreichbarkeit und Bildschirmgrenzen geprüft; ausgewählte Bilder wurden visuell kontrolliert.
- Kataloggenerator, Python-Syntax und `git diff --check` bestanden. Der Katalog enthält in diesem unabhängigen Branch 268 Einträge pro Sprache.

Die Messdatei und vier ausgewählte Aufnahmen liegen in `docs/evidence/arch25-atlas/`. Die Szene verwendet den tatsächlichen Atlas mit kontrollierter Testwelt; die Bilder sind kein Nachweis der Terrainqualität oder Ziel-PC-Leistung. Kein vollständiger Export- oder Gesamtspieltest wurde für dieses UI-Teilpaket behauptet.

Reproduktion nach Godot-Import:

```sh
python tools/localization/catalog.py --check
python tools/validate_godot.py --godot /path/to/godot --skip-main --tests world_map_localization_test world_map_test living_planet_map_test localization_test minimap_test --output /tmp/atlas-validation
xvfb-run -a python tools/review_world_map_localization.py --godot /path/to/godot --output /tmp/atlas-review
```

## Integration

- Die Änderungen sind auf Kartenpräsentation, Kartenmeldungen, Übersetzungskatalog und eigene Tests/Belege begrenzt. Die parallelen ARCH-01/-02/-05/-17/-20/-23/-24/-28/-29-Pakete werden nicht übernommen.
- Beim Zusammenführen mit PR #51 die zusätzlichen Schlüssel beider Änderungen in `localization/catalog.json` vereinigen und anschließend `python tools/localization/catalog.py` ausführen. Die generierten PO-Dateien nicht durch eine einzelne Branchfassung ersetzen.
- Nach Integration des ARCH-29-Registers aus PR #53 `world_map_localization_test` genau einmal unter dem Vertrag `discovery_map` in `tools/validation/contracts.json` registrieren. Das neue Register liegt noch nicht in dieser gemeinsamen Basis; seine unfertige Branchfassung wird hier nicht kopiert. Der bisherige Runner entdeckt den neuen Test bereits automatisch.
- Die gemeinsame Roadmap und den Gesamtstatus von ARCH-25 aktualisiert die Integration. Dieses Teilpaket erklärt andere Bildschirme nicht für abgeschlossen.
