# INT30-23 · Daten-/UI-Prototyp und spätere Anschlüsse

Direkter Nutzerauftrag, zentrale Runde #137. Branch
`agent/int30-23-medieval-tech-prototype`; PR-Ziel
`agent/integration-pt19-20260930`; kein main-Merge.

Feste Basis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree
`5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`.
Geprüfter Implementierungscommit: `74ea354bd29a3a85be32623adf817f69413c194e`,
Tree `e66209981395ff5c11abfb1c769edad5dfc6ee9d`.
Die spätere Beleglieferung verändert ausschließlich Dateien dieses Nachweisordners.

## Lieferung

Neuer exklusiver Bereich `civilization/technology/`, zugehörige UIDs und eigene
Fachtests darin. Fünf stabile Technik-IDs, Schema-/Referenz-/DAG-Prüfung, strukturierte
Sperrgründe und eine separat startbare DE/EN-Oberfläche. Drei Beispielzustände,
flüchtiges Vormerken/Entfernen mit transitiver Bereinigung, Reset, Größenwechsel,
lesbare Scrolldetails und hostgesteuertes Schließen. Alle Wirkungen fehlen noch;
Kosten, Forschungsdauer und Boni sind ausdrücklich vorläufig und unbeziffert.

Start/Prüfbefehle, genaue ID-Zuordnung und Voraussetzungen:
[`civilization/technology/README.md`](../../../civilization/technology/README.md).
Die erste Startmeldung steht in [#137](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5918799674).

`run_preview.py` erzeugt einen separaten temporären Godot-Projektrahmen ohne
Kampagnen-Autoloads und mit isoliertem Benutzerdatenverzeichnis. Die Vorschau
lädt keine laufende Kampagne. Sie kann weder Technologien noch Punkte, Bauwerke,
Kapazität, Transporte oder Vorräte vergeben. `available=false` bleibt auch im
vollständigen Beispielplan zwingend. `civilization_contract.gd`, Epochenfreigabe,
Gebäudeeditor, Entwicklungsbuch, SaveService und Wirtschaft sind unverändert.

## Fachbelege

Die Ergebnisberichte enthalten Engine, Befehle, Ausgangscodes, Erfolgsmarker,
Quellcommit/Tree/SHA256 und Quellenstabilität. Native Aufnahmen sind echte
Godot-Viewportbilder ohne Skalierung oder Nachbearbeitung. Shadercaches werden
als Renderarbeitsdaten ausgewiesen; persistente Nutzerdaten müssen leer bleiben.

Die Katalogprüfung umfasst die fünf stabilen IDs und JSON-Rundlauf, umgekehrte
Katalogreihenfolge, unbekannte Versionen/Abhängigkeiten/Ressourcen/Bauteile,
doppelte IDs/Referenzen, Selbst-/Mehrfach-/Teilgraphzyklen, falsche Feldtypen,
Sperrgründe, Boolean-Nachweise, vorläufige Wirkung, unveränderte Zukunftsdaten und
exakten deutschen Produktvertragswortlaut plus vorhandene DE/EN-Texte.

Die UI-Prüfung verwendet reale MouseButton-/Motion-/Wheel-/Key-Ereignisse:
Szenario wählen, alle Grundlagen vormerken, Lagerung entfernen, abhängige
Vormerkungen verwerfen, Reset, DE/EN, responsive Navigation, Scrollen bis zum
letzten Detailtext, Schließen/Esc und neue Szene ohne alte Beispielzustände.
Die tatsächliche Vorschau-Hostszene wird in einem weiteren Prozess gestartet.

### Tatsächliches Ergebnis

| Prüfung | Ergebnis und Nachweis |
|---|---|
| Katalog-Fachtest | **101 Prüfungen grün**, 1,282 s im finalen Lauf |
| Native UI mit Eingaben/DE/EN/Größenmatrix | **155 Prüfungen grün**, 27,687 s, Compatibility/Mesa llvmpipe |
| Tatsächlicher Vorschau-Szenenstart | **Grün**, separater Prozess, 1,825 s |
| Bilder | **10/10**, Dimensionen und SHA256 in [render/results.json](render/results.json); repräsentative 720p/1080p/800×600-Ansichten gesichtet |
| Persistente Nutzerdaten | **Keine**, Shadercaches getrennt ausgewiesen |
| Bestehende Quell-/Import-/Ressourcenverträge und Wirtschaft | **Grün**, `tribal_economy_progress_test` und `resource_production_contract_test`, [Bericht](consumers/results.json) |
| Gemeinsamer Registry-Append samt Wrapper | **Grün** im getrennten Prüfcheckout mit final identischen Implementierungsdateien, [Bericht](registry/results.json); 16,644 s |
| Geprüfte Implementierungsdateien | SHA256 und vollständiger Gleichheitsabgleich mit dem Registry-Prüfcheckout: [implementation-files.json](implementation-files.json) |
| Konservative Gesamtplanung | **247/247 gewählt, nicht ausgeführt**; vollständige Integration bleibt offen |

Engine: `4.6.3.stable.official.7d41c59c4`; Linux, isolierte Nutzerverzeichnisse,
Software-Mesa 25.2.8 / llvmpipe, kein Ziel-PC-FPS-Nachweis. Finaler Renderbefehl:

```sh
python3 civilization/technology/run_preview.py --godot <Godot-4.6.3> --verify --capture --renderer gl_compatibility --output <isolierter Belegordner>
```

Xvfb innerhalb derselben Ausführungsumgebung gestartet; lokale Umgebung braucht
TCP-Display und `-nolisten unix -listen tcp -ac`. Zehn PNGs sind unveränderte native
Viewportbilder, keine hochgerechneten oder generierten UI-Entwürfe. Die SourceRun-
Manifeste der bestehenden Prüfwerkzeuge liegen platzsparend als `.jsonl.gz` vor;
der Bericht referenziert den SHA256 der unkomprimierten Originale.

Ein früher Lauf auf `b1adad6471371ba415e44bbc1ec4f454779ca9cd` lief bei der ersten
Engineinitialisierung und beim nativen UI-Ablauf in die unveränderte 120-s-Grenze;
9/10 Bilder waren vorhanden. Dieser **fehlgeschlagene** Bericht bleibt unter
[diagnostic-timeout/](diagnostic-timeout/) erhalten. Ein zusätzlicher separater
`--version`-Aufruf blockierte bereits vor Testbeginn. Die finale Version prüft die
Engine direkt anhand jedes tatsächlich geprüften Prozesses und zusätzlich im
Vorschau-Host. Das native Mausrad verwendet begrenzte grobe echte Scrollereignisse
statt einer langen Reihe Einzelereignisse; die Scroll-Endpunktprüfung und alle
fachlichen Erwartungen bleiben erhalten. Testgrenzen wurden nicht erhöht.

Die vorhandenen Wirtschaftstests stammen von der vorbereiteten Implementierung
vor reinen Runner-/Scrollprüfungsänderungen; ihre Fachquellen und deren direkte
Verbraucher sind unverändert. Der finale native Ablauf prüft den aktuellen
Implementierungskopf. Später hinzugefügte Belege ändern ausschließlich diesen
Nachweisordner, keine geprüften Produkt-/Testquellen.

## Getrennte Integration durch die Besitzer

1. **Chat 1 · Sprache:** `civilization/technology/messages.json` ist das konkrete
   Append-Dokument mit DE/EN für den zentralen `localization/catalog.json`.
   Bestehende `TRIBE_RESOURCE_*`-Begriffe nur weiterverwenden. Anschließend den
   vorhandenen Kataloggenerator ausführen. Der Prototyp benötigt seine lokal
   installierten, beim Schließen entfernten Übersetzungen für den Autoload-freien
   Start weiterhin. Keine parallele zentrale PO-/Katalogänderung in diesem PR.
2. **Chat 1 · Testregistry:** [`test-registration.patch`](test-registration.patch)
   fügt genau einen Wrapper `tests/int30_medieval_technology_test.gd` und genau
   einen Registry-Eintrag unter `home_progression` hinzu. Dieser Wrapper startet
   die vorhandenen isolierten Fach-/UI-/Entry-Prüfungen. Gemeinsame Dateien sind
   im Fachbranch unverändert; Patch zunächst im getrennten Prüfcheckout testen.
3. **Chat 1 · Render-CI:** Auf dem aktuellen Merge-Tree unter der vorhandenen
   Godot-4.6.3-/Xvfb-Umgebung den dokumentierten `--verify --capture`-Befehl mit
   Compatibility ausführen und das Ausgabeverzeichnis als Artefakt übernehmen.
   Optional derselbe Ablauf mit Forward+. Keine neue Gesamtregistry und keine
   abweichenden Quell- oder Speicherregeln.
4. **Chat 9 · Entwicklungsbuch:** Nur als getrennten späteren Leseanschluss
   anbieten. `technology_preview.gd` emittiert `close_requested`; ein Buch-Host
   müsste Rücknavigation, Pause, Fokus und Mausmodus selbst erhalten. Hier kein
   Entwicklungsbuch-Button und kein Produktionsanschluss.
5. **Spätere Mittelalter-Runtime:** Echte Nachweise über `Civilization.describe`
   und die bestehende Fortschrittsquelle lesen. Plan-Abhängigkeiten zunächst
   fachlich abnehmen. Erst nach vollständiger Runtime, Produktion/Transport,
   bestätigter Epochenübergabe und geprüfter Save-Migration echte Technologien
   definieren. Beispiel-Facts und `marks` niemals in Kampagnen importieren.

## Grenzen

Eigenständiger Prototyp, keine spielbare Mittelalterphase. Keine Kosten-/Punkte-
Balance, keine Tech-Forschungsdauer, keine Produktions-, Handels-, Wege- oder
Gebäudeplatzierungswirkung. Kein Entwicklungsbuch- oder Save-Anschluss.
Die konservative Änderungsplanung verlangt wegen des neuen, nicht zugeordneten
Bereichs die vollständige Integrationssuite (247 Tests plus Runtime). Ein Plan ist
kein ausgeführter Nachweis. Vier Integrationsgates, native Desktop-Exporte,
Produktions-/Merge-Tree-Abnahme und Ziel-PC-Spieltest bleiben bei der Integration.
