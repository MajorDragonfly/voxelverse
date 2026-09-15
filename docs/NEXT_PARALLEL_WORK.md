# Nächste Voxelverse-Arbeiten

Basis: der feste Quellcommit des gemeinsamen Kandidaten aus
[PROJECT_STATUS](PROJECT_STATUS.md), nicht erneut die veralteten Einzelbranches.
[Integration #93–109 und Ressourcen](INTEGRATION_2026-09-15_RESOURCES.md) enthält die
kurze Lieferliste; die früheren WORK-Berichte bleiben historische Fachnachweise.

## Bereits geliefert

Rüssel, bewegliche Kiefer/Scheren, weitere Schnauzen, Werkstatt DE/EN, HUD,
Dorfaufträge/Berufe, Entdeckungsbuch DE/EN, zweites produktives Lager, Terrainpublikation, Audio-Budget,
Schiffsautoreneditor, Begegnungs-/Labortierarchive, Aufbewahrungsmanifest,
Dorfmessroute und automatische Fachtestauswahl sind im Kandidaten vereinigt.
Beerenbüsche und Nest nutzen die neue deterministische Ressourcendarstellung.
Diese Einstiegsaufträge nicht erneut bearbeiten.

## Abgegrenzte Folgeaufträge

| ID | Ergebnis | Geteilter Bereich |
|---|---|---|
| ARCH-17-PUBLISH-TAIL | Verbleibenden gemessenen Terrain-Engpass bearbeiten | Terrain |
| ARCH-13-RETENTION-LIFECYCLE | Generationen und laufende Schreiber abgrenzen, ohne Dateilöschung | Speicher |
| ARCH-24-PART-REVISIONS | Alte/Neue Teilgeometrie in Entwürfen eindeutig versionieren | Kreaturen/Entwürfe |
| ARCH-25-HUSBANDRY-UI | Restliche Tierhaltungs- und Epochenkopie DE/EN | Dorf/Sprachkatalog |
| ARCH-26-WORKPLACE-INSTANCES | Zwei gleichartige Arbeitsstellen innerhalb eines Ortes | Dorf/Speicher |
| ARCH-27-SITE-TRANSPORT | Tatsächliche Warenbewegung zwischen den beiden Orten | Dorf/Speicher/Transport |
| ARCH-19-TARGET-PC | Festen gemeinsamen Build auf Lars' PC messen | Abnahme |

Ausführbare Briefe: [`tools/workflow/packets.json`](../tools/workflow/packets.json).
ARCH-26 und ARCH-27 nacheinander bearbeiten; Speicheranschlüsse brauchen einen
zugeordneten Integrationsbesitzer. Der Katalog ist keine Live-Belegung.

Kleine Werkzeugfolgearbeit: `validate_godot.py` sollte Quellcommit/Tree sowohl vor
als auch nach einem Lauf erfassen und zwischenzeitliche Änderungen sichtbar
machen. Derzeit wird die Revision erst beim Schreiben von `results.json` gelesen;
die aktuelle Integration dokumentiert den Start und ihre Deltas gesondert.

```sh
python3 tools/work_packet.py list
python3 tools/work_packet.py show ARCH-17-PUBLISH-TAIL
python3 tools/validate_godot.py --changed-since BASIS_SHA --plan
```

Ein Fachchat prüft geänderten Ablauf und direkte Verbraucher. Volle Suite,
Produktions-/Reisekette, Desktopexport und nativer Spieltest gehören zur gemeinsamen
Integration. Kein mehrfacher Vollabgleich desselben unveränderten Quellstands.

Spätere Ziele aus [ROADMAP](../ROADMAP.md) bleiben erhalten: Gebäudeeditor erst
Mittelalter, eigene Spezies entwickelt Zivilisation, Epochenwechsel wird bestätigt,
Schiffeditor allein schaltet keine Weltraumphase frei. Pause und geschlossene App
produzieren nichts. Keine zweite Speicher-, Tier- oder Produktionsarchitektur.
