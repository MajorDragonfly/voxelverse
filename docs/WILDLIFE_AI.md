# Wildtier-KI: Wahrnehmung und lokale Bewegung

Auftrag: die KI der anderen Kreaturen verbessern und die parallelen Chats
weiterhin getrennt halten. Dieses Paket baut auf der abgeschlossenen Heimgruppe
aus PR #20 auf. Es wird kein Fremdbranch integriert.

## Verhalten im Spiel

- Tiere berücksichtigen tatsächlichen Sichtkontakt. Im Nahbereich nehmen sie
  Gefahren aus allen Richtungen wahr; weiter entfernt gilt ein Sichtfeld.
  Eine Wand unterbricht die Wahrnehmung und verhindert auch Nahkampftreffer.
- Räuber warnen zunächst 0,9 Sekunden. Sie verfolgen höchstens acht Sekunden
  bzw. innerhalb eines 20-m-Reviers. Nach verlorener Sicht suchen sie nur den
  zuletzt gesehenen Ort, nicht die aktuelle Position hinter einem Hindernis.
  Danach kehren sie zum Ausgangsort zurück und ruhen fünf Sekunden.
- Friedliche Wildtiere fliehen vor wahrgenommenen Bedrohungen und nahen Räubern.
  Stark verletzte Räuber fliehen ebenfalls. Kurze Gefahrenerinnerung verhindert
  einen sofortigen Wechsel zurück zum Wandern bei einer Sichtunterbrechung.
- Sichtbare Tiere derselben Spezies schließen aufeinander auf. Ein Abstand von
  etwa 1,8 m verhindert dichtes Übereinanderstehen. Dieses Verhalten betrifft
  vorhandene Individuen; es erhöht nicht die Population und erzeugt keine
  zusätzlichen Tiere oder Nestmitglieder.
- Lokale Kollisionsprüfungen umgehen Bäume und kurze Mauern. Kleine Stufen sind
  erlaubt, steile Abbrüche, versperrte Durchgänge und tieferes Wasser werden
  vermieden. Ein Tier wartet, wenn es keinen sicheren lokalen Weg findet.
  Ohne geladenen Boden bleibt es stehen, bis Boden verfügbar ist.
- Kurze Hinweise über nahen Tieren zeigen unter anderem „Warnt“, „Flieht“,
  „Sucht Anschluss“ oder „Weg blockiert“. Ruhe und gewöhnliches Wandern werden
  nicht ständig beschriftet.

## Abgrenzung und Anschlüsse

Nur `creatures/wildlife/procedural_wildlife_v7.tscn` wechselt seinen Script-Einstieg
von V8 zur neuen, von V8 abgeleiteten `creatures/ai/wildlife_brain.gd`.
`wildlife_steering.gd` enthält die begrenzten Sicht- und Kollisionsprüfungen.
Der bestehende Spawner erzeugt dadurch automatisch Tiere mit dieser KI.

Die vorhandenen V7-/V8-Skripte, der Spawner, Renderer, Editor, Skilltree,
Speicherdienst, Artenbuch und die Audio-Signale werden nicht überschrieben.
Die Vererbung erhält Bauplanerzeugung, Identitäten, Interaktion, Inspektion,
Schadensmeldungen, Trefferreaktion, Tod und Kadaver. Neue Inspektionsfelder:
`ai_state` und `ai_description`; `get_ai_debug_state()` liefert Diagnosedaten.

Der Verhaltens-Chat bleibt für Befreunden, Helfen, Beziehungen und Punkte
zuständig. Ein vorhandenes `SocialBehavior.controls_movement()` mit aktivem
`attention_remaining` erhält Vorrang. `SocialBehavior.entry().relation == ally`
schließt den Spieler als Bedrohung aus, auch wenn das Tier vor einem externen
Angreifer flieht. Der Vertrag wurde mit einem kontrollierten Anschluss geprüft;
das ist keine behauptete Zusammenführung oder Gesamtprüfung des Fremdbranches.

Die KI schreibt keine Beziehungen, Entdeckungen, Verhaltenspunkte oder zusätzlichen
Kampagnendaten. Wahrnehmung, Warnzeiten, kurzer Weg und Suchgedächtnis sind
flüchtiger Laufzeitzustand. Die dauerhafte Wildtieridentität und Gesundheit werden
weiterhin vom zuständigen Spawner-/Begegnungspaket bestimmt. Es werden keine
unfertigen Folgephasen freigeschaltet.

## Grenzen und Kosten

Die Bewegung gilt für die bestehende ebene `legacy_plane_v9`-Oberfläche. Globale
Wegsuche, Navigation auf der Kugeloberfläche, Schwimmen/Fliegen, Nahrungssuche,
individuelle Hunger-/Durstwerte sowie Jagd zwischen Tieren sind nicht Teil dieser
Lieferung. Insbesondere wird beim sichtbaren Fliehen vor einem Räuber keine
neue Räuber-Beute-Schadens- oder Belohnungssimulation behauptet.

Wahrnehmung läuft alle 0,2 Sekunden, Steuerung alle 0,1 Sekunden; höchstens 32
nahe Tiere werden je Entscheidung betrachtet. Die vorhandene Populationsgrenze
bleibt maßgeblich. Das ist eine lokale Laufzeit-KI für die sichtbaren Vertreter
der Regionalökologie, keine Galaxiesimulation aller Individuen.

## Prüfung

```sh
python tools/validate_godot.py --godot /path/to/godot --output /tmp/wildlife-ai
```

- `tests/wildlife_ai_test.gd`: echte Wildtierszene und Physik; Sichtbarriere,
  Blickrichtung, Warnzeit, Nahkampf ohne Wandtreffer, letzte bekannte Position,
  Verfolgungsende, tote Ziele, Herdenabstand, Sozialanschluss, Hindernisumgehung,
  Klippe, Wasser und Wiederaufnahme nach Boden-Streaming. Kein unbeabsichtigter
  Fortschritts- oder Beziehungsertrag.
- `tests/wildlife_ai_world_test.gd`: die normale Main-Szene mit tatsächlichem
  Fauna-Streaming, generiertem Gelände, vorhandenen Populationsgrenzen, sichtbarer
  Bewegung, Bodenkontakt, erhaltenen Inspektions-/Identitäts-APIs und Speichern/Laden.
- Beide Tests unterstützen `-- --capture /absolute/directory` für grafische
  Prüfungen ohne `--headless`. Release-PCKs können außerhalb des Quellprojekts
  mit einer externen Kopie der Tests und dem Editor geprüft werden.

Der Windows-Testexport bekommt ausschließlich beim Export den eigenen
Anwendungsnamen `Voxelverse-Wildtier-KI-Test` und damit einen getrennten
Spielstand. Er enthält Heimgruppe und diese KI auf der stabilen M2A-Basis;
aktuelle Fremdbranch-Grafik, Menüs und Sozialaktionen sind separat.
