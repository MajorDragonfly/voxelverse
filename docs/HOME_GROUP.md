# Heimat und Nestgruppe

Eigenes, spielbares Paket auf `agent/home-group`, aufgebaut auf dem abgeschlossenen
M2A-Stand `f01532416674cc2202aca1a6a99c45cd91d559e0`. Keine unfertigen
Editor-, Planeten-, Menü-, Artenbuch-, Verhaltens- oder Sound-Arbeiten integriert.

## Im Spiel

- **N** öffnet „Heimat & Gruppe“. H bleibt für die Hilfe-Aktion des parallelen
  Verhaltenspakets frei. Mit N, Escape oder dem Zurück-Button weiterspielen.
- Auf freiem, ebenem, trockenem Boden einen Heimatplatz gründen. Dort entstehen
  einmalig zwei dauerhafte Gefährten der eigenen Spezies, zunächst wartend.
- **Folgen**, **Warten** und **Heimkehren** gelten für alle oder einzelne Mitglieder.
- Der bestehende Nestpunkt wird versetzt und damit auch der vorhandene
  Wiederbelebungspunkt. Ein Umzug erzeugt keine weiteren Gefährten und teleportiert
  keine bestehenden Mitglieder.
- Im Umkreis von 3,5 Metern um die Heimat regeneriert die Spielfigur langsam
  Gesundheit, wenn Hunger und Durst jeweils über 25 liegen. Keine Nahrung oder
  Verhaltenspunkte werden verschenkt.
- Heimat, stabile Mitgliedsidentitäten, Befehle und Positionen werden im normalen
  Kampagnenspielstand gespeichert. Gründung und Befehle speichern sofort.

## Abgrenzung für die spätere Übernahme

Einziger veränderter bestehender Einstieg ist `world/resources/nests/nest.tscn`:
ein neuer Controller als Kind des vorhandenen Nests. Alle übrigen Dateien dieses
Pakets liegen in neuen Pfaden. Keine Änderungen an Main, Projektkonfiguration,
Spielersteuerung, SaveGameService, CampaignState, Skilltree, Wildtier-KI, Editor,
Terrain, Audio oder gemeinsamem HUD. Bestehende Renderer und Laufanimationen
werden über ihre vorhandenen Schnittstellen verwendet.

Das sind **eigene Nestbewohner**, keine rekrutierten Wildtiere. Beziehungen,
Befreunden, Helfen, Angriff und Verhaltensbelohnungen bleiben Aufgabe des
Verhaltenspakets. Die späteren Spielphasen werden nicht freigeschaltet.

Speicherort: `campaign.bodies[integer_seed_as_string].home_group`, Schema 1.
Bestehende Kampagnenleser übernehmen den vollständigen `bodies`-Inhalt; ein
zusätzlicher Speicherpfad oder eine Änderung des globalen Speicherschemas entfällt.
Unbekannte oder ungültige Gruppendaten bleiben unverändert erhalten und sperren
Gruppenaktionen. Bei fehlgeschlagenem Speichern wird die Aktion zurückgenommen.
Ein neuer Kampagnenstart setzt auch Nestgruppen zurück. Verschiedene Planeten
besitzen eigene Gruppen; ein Besuch stellt dieselben Identitäten wieder her.

## Grenzen dieses Pakets

Die Begleiter bewegen sich physisch in der geladenen Umgebung auf der bisherigen
ebenen Planetenoberfläche (`legacy_plane_v9`). Sie umgehen kleine Hindernisse,
warten vor steilen Kanten, Wasser oder unpassierbaren Wegen. Es gibt noch keine
weltweite Wegsuche. Außerhalb von 90 Metern bzw. ohne geladenen Boden pausiert
ihre Darstellung/Bewegung am gespeicherten Ort. Heimkehren über größere Distanzen
erfordert deshalb, in der Nähe zu bleiben. Kein Teleport zu einem fernen Ziel.

Keine Vorräte, Nestverteidigung, Gebietsansprüche, globale Gruppensimulation oder
zusätzliche Bewohner in diesem ersten Paket. Die spätere Zusammenführung mit den
anderen Chat-Branches braucht einen gemeinsamen Laufzeittest; dieser Branch
behauptet keine bereits geprüfte Gesamtintegration.

## Prüfung

Godot 4.6.3; isolierte Benutzerdaten für alle Prüfungen:

```sh
python tools/validate_godot.py --godot /path/to/godot --output /tmp/home-checks
```

Der bestehende CI-Runner entdeckt die neuen Tests automatisch:

- `tests/home_group_test.gd`: echte Tastatur- und Mausklicks, Pause/Mausbesitz,
  Animation/physische Bewegung, Einzelbefehle, Hindernisse, Umzug ohne Duplikate,
  Rast, Distanzpause, Save-Rollback, Neustart in einem zweiten Prozess,
  unbekanntes Schema, Laden, Planetenwechsel und neue Kampagne.
- `tests/home_group_world_test.gd`: echte Main-Szene, generierter Startplanet,
  begehbarer Heimatplatz, Bodenkontakt beider Bewohner und erneutes Laden.

Beide Tests akzeptieren `-- --capture /absolute/output/directory` für sichtbare
Fenstertests und Screenshots. Dafür Godot ohne `--headless` starten.
