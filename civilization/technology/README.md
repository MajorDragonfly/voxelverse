# INT30-23 · Mittelalter-Technikprototyp

Eigenständiger Daten- und UI-Prototyp auf der festen INT30-Fachbasis
`2b1ac023db4074c2ce6b7db8fbab09ab929a8435`. Kein Kampagnenanschluss.

Mit Godot **4.6.3** und Python 3 starten, vom Repository-Verzeichnis:

```sh
python3 civilization/technology/run_preview.py --godot /pfad/zu/godot
```

Unter Windows denselben Befehl mit `python` und dem Pfad zur Godot-EXE benutzen.
Der Starter erzeugt ein temporäres Projekt mit vorhandenen Quelldateien,
eigenem Benutzerdatenverzeichnis und **ohne Autoloads**. Keine Kampagne, kein
SaveService und keine Wallet laufen. Der Starter funktioniert auch ohne
Symlink-Berechtigung über temporäre Kopien. Nicht die Vorschau aus dem regulären
Spielprojekt starten: dessen Autoloads gehören zum Spiel, nicht zum Prototyp.

Der Szenarioknopf schaltet zwischen drei ausdrücklich beispielhaften Zuständen:
ohne Stammesnachweise, versorgtes Stammesdorf und vollständiger Vorschauplan.
Ein Klick auf den Sprachknopf wechselt DE/EN ohne Geräteeinstellungen zu speichern.
Techniklinks in der Seitenleiste oder Zurück/Weiter im kompakten Fenster öffnen
Details. Vormerken setzt ausschließlich flüchtige Vorschaukennzeichnungen.
Entfernen einer Grundlage entfernt alle davon abhängigen Vormerkungen. Reset und
Neustart verwerfen alle Beispieleinstellungen. Schließen und Esc gehen über
`close_requested` an den separaten Host.

## Katalog und Herkunft

`catalog.json`: Schema 1, Revision 1, Phase 2, `scope=preview_only`.
IDs und Fachbezüge bleiben sprachunabhängig. Ressourcenlisten sind Bezüge, keine
Baukosten. Bauteile sind vorhandene Designbegriffe, keine Produktionsfreigaben.

| Stabile ID | Grundlage | Vorläufige Technikabhängigkeit | Bestehende Stammesnachweise |
|---|---|---|---|
| `medieval.housing` | Wohnbau | keine | `housing` |
| `medieval.storage` | Lagerung | Wohnbau | `supply` |
| `medieval.crafting` | Handwerk | Lagerung | `craft`, `professions` |
| `medieval.roads` | Wege | Wohnbau | `professions` |
| `medieval.trade` | Handel | Lagerung, Handwerk, Wege | `neighbors`, `supply` |

Stammesnachweise verwenden IDs, unterstützte Zustände und Wortlaut aus
`core/progression/civilization_contract.gd`, Phase 2. Der DE-Abgleich prüft den
vollständigen Wortlaut einschließlich 180 Sekunden, 12 Nahrung/6 Wasser und
Nachbarlieferung 6 Nahrung/4 Holz. Der Mittelalter-Spielablauf mit Siedlungen,
Handwerk, Wegen und Handel kommt aus demselben `runtime`-Vertrag; begehbare
Verbindungen und Ziel-Lagerungen stehen auch im Phase-3-Handelsvertrag. Daraus
wird **keine** zusätzliche Stammesbelohnung abgeleitet.

Die Auswahl der Nachweise pro Technik und die Reihenfolge der fünf Techniken
sind **vorläufige Entwurfsentscheidungen**, keine bereits geltenden Freischaltregeln.
Kosten, Dauer und Boni bleiben absichtlich unbeziffert. `implemented=false`,
`balance=provisional` und `available=false` gelten selbst bei vollständig
vorgemerktem Vorschauplan. Die bestehende Mittelalter-Epochenfreigabe bleibt
unverändert gesperrt. Der Gebäudeeditor ist gemäß Produktvorgabe erst für das
Mittelalter vorgesehen und wird hier weder geöffnet noch freigeschaltet.

Bestehende Begriffe: `resource_catalog.gd` (Holz, Stein, Nahrung, Wasser, Fasern)
und `building_part_library.gd` (Hauskern, Holztür, Werkstatt, Marktflügel, Marktdach).
Wege und Lagerung erhalten keine erfundenen Bauteilkennungen. Der vorhandene
Werkstattbauteil ist ein Entwurfsbezug; seine Industriestatistik wird nicht angewandt.

## Prüfungen

```sh
python3 civilization/technology/run_preview.py --godot /pfad/zu/godot --verify --output ../int30-tech-checks
```

Headless: Katalog-Fachtest, echte Maus-/Tastatur-UI-Prüfung und tatsächlicher
Szenenstart. Der Starter prüft Godot-Version, Prozessausgang, Erfolgsmarker,
Fehler-/Leak-Logs, Quellintegrität und fehlende persistente Nutzerdaten.
Shadercaches sind Renderarbeitsdaten und werden getrennt ausgewiesen.

Auf einer grafischen Sitzung (Linux CI unter Xvfb) für zehn native Aufnahmen:

```sh
python3 civilization/technology/run_preview.py --godot /pfad/zu/godot --verify --capture --renderer gl_compatibility --output ../int30-tech-gl
```

Matrix: DE/EN × 1280×720/100 %, 800×600/150 %, 1920×1080/100 %;
zusätzlich vollständiger Vorschauplan und durch Mausrad erreichbare letzte Details.
`--renderer forward_plus` nutzt denselben UI-Prüfablauf. Ergebnisse müssen außerhalb
des Checkouts geschrieben werden, damit die Quellintegritätsprüfung unabhängig
vom Belegordner bleibt. Aufnahmeanzahl, PNG-Dimensionen und SHA256 stehen im Bericht.

Eigene Fachtests liegen innerhalb dieses neuen Bereichs. Der bestehende
Registry-Runner führt nur registrierte Tests unter `tests/` aus. Die getrennte
Übergabe enthält einen einzelnen Wrapper samt Registry-Patch für Chat 1; dieser
Patch wird hier nicht auf gemeinsame Dateien angewandt.

## Späterer Produktionsanschluss

Siehe die getrennte [Übergabe](../../docs/evidence/int30-23-medieval-tech/HANDOFF.md).
Entwicklungsbuch bleibt bei Chat 9. Eine spätere lesende Projektion muss echte
Nachweise aus `Civilization.describe(...)` verwenden, den gemeinsamen SaveService,
stabile Fraktions-/Design-IDs und sichere bestätigte Epochenübergabe erhalten.
Vorschauvormerkungen und Beispielszenarien dürfen niemals in echte Technik- oder
Punktestände importiert werden. Wirtschaft, Transport, Bauplatzprüfung, Produktion,
Speichermigration und Freischaltung sind eigenständige Folgearbeit.
