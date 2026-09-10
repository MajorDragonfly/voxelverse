# Übergabe BP-COMMUNITY.2

Am 10. September 2026 in diesem Chat reserviert und umgesetzt:
**Lokale Kreaturenvorlagen, sichtbarer Import/Export und wählbare Startkreaturen.**

- Branch: `agent/community-blueprint-library-2026-09-10`.
- Basis: BP-COMMUNITY.1, [PR #61](https://github.com/MajorDragonfly/voxelverse/pull/61),
  Quellbaum `8fc08ba76970716212daa53667f047b462318dc5`.
- Reihenfolge: ARCH-23 ([PR #50](https://github.com/MajorDragonfly/voxelverse/pull/50))
  → BP-COMMUNITY.1 → dieses Paket. Der eigene PR richtet sich zunächst gegen
  `agent/community-blueprint-contract-2026-09-10`.
- Umfang und Bedienung: [COMMUNITY_BLUEPRINT_LIBRARY.md](COMMUNITY_BLUEPRINT_LIBRARY.md).
- Nachweise: [COMMUNITY_BLUEPRINT_LIBRARY_VALIDATION.json](COMMUNITY_BLUEPRINT_LIBRARY_VALIDATION.json).

## Gelieferter Ablauf

Im Editor eine Vorlage mit echter Vorschau wählen, in einem Schritt übernehmen,
rückgängig machen/wiederholen und regulär speichern. Eigene Entwürfe mit neuer
Kennung lokal ablegen, exportieren, von einer Datei importieren und nach Neustart
weiterverwenden. Gleiche Revisionen kollidieren nicht stillschweigend. Im Startmenü
eine von drei Anfangskreaturen oder eine geeignete lokale Vorlage auswählen und
damit die normale Kugelkampagne starten. Kein fremder Fortschritt wird übertragen.

## Integrationspunkte und parallele Arbeit

Andere Fachzweige wurden nicht integriert. ARCH-28 bleibt beim vom Benutzer
benannten Chat. Auch die bekannten Reservierungen ARCH-01, -02, -05, -13, -14,
-17, -18, -20, -21, -24, -25 und -29 werden nicht übernommen.

Die neue Funktion liegt überwiegend in `assembly/exchange/` und `ui/blueprints/`.
Folgende kleine Anschlüsse berühren gemeinsam genutzte Dateien und müssen bei der
Integration mit den jeweiligen Besitzern zusammengeführt werden:

- `save_game_service.gd`: optionaler Vorlagenparameter ausschließlich in
  `create_slot`, Vorprüfung und initialer eigener Entwurf. Kein Umbau von
  Sicherungshistorie, Regionen, Phasenübergaben oder Reisespeicherung.
- `session_flow.gd`: optionalen Parameter in `new_game` durchreichen.
- `main_menu.gd`: Auswahl und Zusammenfassung der Startkreatur; Scrollen zum Fokus.
- `creature_editor_runtime.gd`: Palette öffnen, Kontext prüfen und vorhandenen
  Undo-/Speicherweg verwenden. Kein Eingriff in den Körperteil-Geometrieanbieter.
- `localization/catalog.json`: neue `BP_*`-Einträge mit DE/EN. Mit parallelen
  Katalogergänzungen zusammenführen und PO-Dateien danach gemeinsam erzeugen.
- ARCH-29: Die Basis findet `*_test.gd` automatisch. Bei Übernahme des neuen
  Prüfkatalogs die beiden zusätzlichen Tests explizit berücksichtigen:
  `creature_design_library_test`, `creature_library_ui_test`.

## Reproduzieren

```sh
python3 tools/localization/catalog.py --check
python3 tools/validate_godot.py --godot /path/to/godot-4.6.3 --skip-main --tests creature_design_library_test creature_library_ui_test community_blueprint_package_test creature_studio_test save_slots_test localization_test frontend_test
```

Für native Bilder denselben UI-Test mit einem verfügbaren Display und isolierten
Godot-Benutzerdaten starten:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tests/creature_library_ui_test.gd -- --capture-dir /absolute/output/path
```

Jeder Prüflauf benötigt ein frisches, isoliertes Benutzerverzeichnis: `tools.validation_support.isolated_env` und
`validation_editor` verwenden, damit vorhandene Spielstände und selbstenthaltene
Editorinstallationen nicht berührt werden. Der UI-Test verändert absichtlich
Fenstergröße/Sprache und erzeugt eigene Testkampagnen.

## Nächster abgegrenzter Auftrag

BP-COMMUNITY.2 ist auf diesem Fachbranch erledigt. Ein anschließender Auftrag kann
**BP-COMMUNITY.3: gemeinsamer Vorlagenkatalog mit bewusstem Herunterladen** sein.
Er muss die vorhandene Paketprüfung und lokale Kopie verwenden; Anmeldungen,
Dienstbetrieb und öffentliche Uploads benötigen einen eigenen konkret festgelegten
Umfang. Dieses Folgepaket ist hier nicht reserviert oder umgesetzt.
