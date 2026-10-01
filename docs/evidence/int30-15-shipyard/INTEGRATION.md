# INT30-15 Werft: Anschlüsse an Chat 1

Feste Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`.
Schreibbereich: `space/ships/shipyard.gd`, eigener lesender Präsentationshelfer,
eigener Fachtest und Aufnahmehelfer. Schiffsformat, Module, Flotte,
DesignStore und Kampagnenfreischaltungen sind unverändert.

## Gemeinsamer Sprach-/Registry-Patch

`chat1-shared.patch` enthält ausschließlich den Kataloganschluss und die
Registrierung von `shipyard_presentation_test` im vorhandenen Vertrag
`expedition_design`. Die gemeinsamen Dateien werden nicht im Fachcommit verändert.
Für lokale Prüfungen wird genau dieser Patch vorübergehend angewendet.

Chat 1 wendet den Patch vor der Fachintegration an und erzeugt anschließend mit
`python3 tools/localization/catalog.py` die bestehenden DE/EN-PO-Dateien neu.
Falls andere Fachlieferungen den gemeinsamen Katalog bereits erweitert haben,
werden stattdessen die Zeilen aus `catalog-additions.json` anhand ihrer Schlüssel
in `localization/catalog.json` eingefügt. Vorhandene Zeilen nicht ersetzen.
Den neuen Test genau einmal im bestehenden Vertrag registrieren.

Ohne diesen Anschluss liefert der Fachbranch neue Sprachschlüssel und einen noch
nicht registrierten Test; er ist deshalb bis zum Anschluss ein Integrationsentwurf.
Die neuen Modulnamen sind reine Anzeige. Bestehende Entwurfsnamen (auch
„Pionier“, „Späher“ und der bisherige Kopiennamenszusatz), Modul-IDs, Kategorien
und gespeicherte Revisionen werden nicht übersetzt oder migriert.

## Fachprüfung

```sh
python3 tools/validate_godot.py --contracts expedition_design --skip-main --output CHECK_DIR
python3 tools/review_shipyard_presentation.py --godot GODOT --output INPUT_DIR
xvfb-run -a -s '-screen 0 1920x1080x24' python3 tools/review_shipyard_presentation.py --godot GODOT --capture --output RENDER_DIR
```

Der Aufnahmehelfer verwendet isolierte Nutzerdaten und einen zweiten echten
Engineprozess für Original-/Kopien-Wiederaufnahme. Der native Lauf trennt
Expedition, Beiboot, Präsentation und Layout in vier begrenzte Engineprozesse
mit denselben isolierten Nutzerdaten; anschließend folgt die Wiederaufnahme.
Seine Bilder stammen aus
der Produktionsszene, ohne nachgezeichnete Oberfläche. Die Headless-Variante
prüft tatsächliche Hauptfenster-Eingaben; native Dialoge ohne Clientfläche
werden dort über ihren vorhandenen Anschluss geprüft. Der gerenderte Lauf
prüft die Dialoge zusätzlich über echte Mausereignisse im eingebetteten Fenster.

Der konservative Gesamtplan fordert wegen gemeinsamem Katalog/Registry und
unbekannter neuer Helfer die volle Integration. Die Fachprüfung ersetzt diese
Suite und die vier Gates auf dem neuen Integrations-Tree nicht. Keine Freigabe
für main, Ziel-PC-Leistung oder die Weltraum-Spielschleife.

Bei vielen parallelen Kampagnenprüfungen kann der Aufnahmehelfer zusätzlich
`--authoring-profile` verwenden. Er erzeugt dann ein temporäres Projekt mit den
unveränderten Produktionsdateien und nur LocaleManager/DisplaySettings als
Autoloads. Das Profil und seine SHA256 werden im Ergebnis ausgewiesen. Es
prüft keine Kampagnen-Autoloads. Das ursprüngliche Projektprofil bleibt die
Vorgabe ohne diese Option. Lokales Software-Rendering nutzt bei Bedarf
`LIBGL_ALWAYS_SOFTWARE=1 LP_NUM_THREADS=2`; daraus werden keine FPS-Werte abgeleitet.

Konkrete Ergebnisse, Quellstände und gerenderte Ansichten stehen in
[VERIFICATION.md](VERIFICATION.md).
