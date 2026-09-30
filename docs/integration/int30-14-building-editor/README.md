# INT30-14: Anschluss an Chat 1

Feste Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`.
Die Schreibzuordnung für BuildingBuilder und eigene Editorhelfer ist in der
aktuellen Runde in Issue #137 bestätigt. Assembly, BuildingBlueprint,
Teilebibliothek und DesignRegistry bleiben unverändert. Die vorhandene
Mittelalter-Freischaltung und die Stammes-/Dorfwege werden nicht geändert.

## Erforderliche Anschlüsse

1. Die **139 neuen Nachrichten** aus `catalog-messages.json` an die vorhandene
   Liste `localization/catalog.json` anhängen. Jede Kennung genau einmal.
   `catalog.patch` zeigt denselben Append auf der festen Fachbasis; bei zwischenzeitlichen
   Append-Änderungen die Nachrichten ergänzen, keinen älteren Gesamtkatalog ersetzen.
2. `python3 tools/localization/catalog.py` ausführen und die erzeugten DE/EN-Dateien
   mit dem zentralen Anschluss committen.
3. `building_editor_input_test` genau einmal unter dem vorhandenen Vertrag
   `blueprints` in `tools/validation/contracts.json` registrieren. `registry.patch`
   enthält die enge Änderung auf der gemeinsamen Basis.
4. `ci.patch` schlägt den eigenen grafischen Editorlauf vor. Chat 1 besitzt
   `.github/`; auf diesem Fachbranch wird kein Workflow eingetragen.

Die Katalog-/Registry-Abhängigkeiten müssen **vor der Abnahme des neuen Merge-Trees**
integriert sein. Auf dem rohen Fachbranch ist der neue Test absichtlich noch nicht
zentral registriert. Die lokale Prüfung verwendet einen getrennten Git-Worktree mit
exakt identischem Fachcode plus diesen Anschlüssen; das ist kein Beleg einer bereits
veröffentlichten Zentralintegration.

## Fachprüfung

```sh
python3 tools/validate_godot.py --godot /path/to/godot-4.6.3 \
  --tests building_editor_input_test modular_assembly_framework_test \
  blueprint_contract_test campaign_foundation_test coordinate_persistence_test \
  --skip-main --output /tmp/building-editor-checks
```

Der Eingabetest öffnet die vorhandene Szene und schickt echte Maus-/Tastenereignisse
an deren Controls. Er prüft numerische Achsenwerte, bestehende Rasterung,
ungerasterte ältere Fenster, Historie und eindeutige Duplikat-UIDs, Hinzufügen,
Löschen bis zur leeren Liste, Sprachwechsel während einer Eingabe, Namen mit
Schlüssel-/Platzhaltertext, Speichern/Laden und einen frischen Engine-Prozess.
Die Nutzerverzeichnisse sind durch den bestehenden Runner isoliert.

```sh
xvfb-run -a -s '-screen 0 1920x1080x24' \
  python3 tools/review_building_editor.py --godot /path/to/godot-4.6.3 \
  --output /tmp/building-editor-review
```

Der Grafikrunner benötigt einen echten Displayserver und erzwingt sieben native
PNG-Aufnahmen: DE/EN in 800×600, 1280×720 und 1920×1080 sowie die leere Auswahl.
Er prüft Abmessungen und Logs, unveränderte Quellbytes und einen weiteren Prozess
nach dem Schließen des nativen Editors. Headless-Renderbilder werden abgelehnt.
Ein Timeout ist ein gescheiterter Lauf und kein Sichtnachweis.

## Anschlussgrenzen

Chat 17 liefert Gebäudeaustausch nur als getrennten Editoranschluss; Chat 25
liefert die Vorlagenauswahl genauso. Diese Funktionen sind nicht Teil dieser
Lieferung. Es entstehen weder Gebäudeinstanzen noch Dorfproduktion.
Vollsuite, vier Integrationsgates, Desktop-Exporte und Ziel-PC-/Epochenfreigabe
bleiben eigene Integrationsnachweise. Kein main-Merge oder Auto-Merge.
