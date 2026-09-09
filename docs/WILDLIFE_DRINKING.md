# Durst und selbstständiges Trinken

Separates Paket auf dem abgeschlossenen eigenen Nahrungssuche-Paket
`agent/wildlife-foraging` / PR #24. Kein anderer Zweig wurde übernommen.

## Spielablauf

- Die Landrollen `grazer`, `forager`, `climber`, `predator` und `scavenger`
  erhalten einen Wasservorrat (`hydration`) von 0 bis 100. Der Anfangswert
  variiert deterministisch zwischen 40 und 90. Aktive Tiere verlieren 0,16
  Punkte pro Simulationssekunde und suchen unter 45 nach Wasser.
- Die KI fragt die bestehende Wasserlogik des aktuellen Planeten ab. Als
  Trinkwasser zählen tatsächlich überflutete Bereiche, die der Generator als
  `lake` oder `river` ausweist. Reine Ozeanflächen werden ausgeschlossen.
  Dies ist eine Spielregel nach Gewässertyp, keine chemische Salzsimulation.
- Die Ufersuche läuft in kleinen Paketen: vier Proben pro Sinnesaktualisierung,
  höchstens 80 Proben pro Suchdurchgang, anschließend zwei Sekunden Pause.
  Der Suchradius reicht bis 14 Meter; mögliche Standplätze bleiben innerhalb
  von 16 Metern und des bestehenden Revierlimits.
- Ein Standplatz benötigt geladenen, ausreichend flachen, trockenen Boden,
  Platz für den Körper und freie Sicht. Die bisherige Hindernissteuerung
  führt das Tier dorthin. Ohne Fortschritt wird der Kandidat verworfen;
  ein Anlauf endet spätestens nach 14 Simulationssekunden.
- Getrunken wird erst mit tatsächlichem Bodenkontakt, höchstens drei Metern
  Abstand zum Wasser und höchstens 1,25 Metern Höhendifferenz. Der Uferboden
  muss oberhalb des Wassers liegen. Auch unter dem Wasserziel muss ein
  geladenes, überflutetes Bett nachweisbar sein. Eine Wasserfläche allein
  genügt damit nicht, wenn die zugehörige Umgebung ausgeladen wurde.
- Pro 0,8 Simulationssekunden werden 12 Punkte aufgefüllt. Ab 80 beendet das
  Tier das Trinken und ruht kurz. Die Anzeigen ergänzen „Sucht Wasser“ und
  „Trinkt“; die vorhandene Inspektionsschnittstelle liefert `hydration`.

Gefahr und soziale Aufmerksamkeit haben weiterhin Vorrang. Ist Hunger vor
Beginn einer Wasserroute dringender, bleibt das Tier zunächst bei der Mahlzeit.
Kritischer Durst (höchstens 25) hat Vorrang, sobald eine geeignete Wasserstelle
gefunden wird. Ein gewählter Wasserweg wird beibehalten, damit die KI nicht
zwischen Essen und Trinken pendelt. Fehlendes Trinkwasser blockiert weder
Nahrungssuche noch das bisherige Herden- und Wanderverhalten.

## Speicherung und Zuständigkeiten

`campaign.bodies[str(int(seed))].wildlife_drinking` enthält Schema 1,
Körper-ID und `animals[object_id] = {hydration, seeking}`. Die Objekt-ID kommt
unverändert aus der bestehenden Kreaturenidentität. Der normale Kampagnensave
erfasst die Werte; es gibt keine zweite Datei oder Schreibvorgänge pro Schluck.

Beim Laden binden sich aktive Tiere an den geladenen Datensatz. Konkrete
Uferziele, Suchfortschritt und Schlucktimer werden verworfen und anhand der
geladenen Welt neu ermittelt. Ein neues Individuum mit neuer Objekt-ID besitzt
eigene Bedürfnisse; die Identitätsvergabe und Platzierung des Fauna-Streamers
werden hier nicht ersetzt.

Unbekannte Versionen, falsche Körperzuordnung und ungültige Einträge bleiben
unverändert. Die Tabelle ist auf 32.768 Individuen je Körper begrenzt; neue
Einträge werden bei Erreichen der Grenze blockiert, bestehende nicht gelöscht.
Alte Spielstände ohne die Erweiterung erhalten sie beim ersten Landtier.

Hungerstand, Beerenvorräte, Sozialbeziehungen, Entdeckungen, Belohnungen,
globale Speicherversionen und Phasenübergänge behalten ihre bisherigen
Zuständigkeiten. `drinking_brain.gd` erweitert die abgeschlossene Nahrungssuche;
einziger geänderter bestehender Einstieg ist der Skriptpfad der Wildtierszene.

Der Wasseradapter verwendet standardmäßig `WorldGenerator` mit
`get_water_info`, `get_water_level` und `get_terrain_height`. Vor Eintritt in
den Szenenbaum kann ein anderer Anbieter über `water_provider` gesetzt werden.
Die kontrollierte Verhaltenstestszene nutzt diesen Anschluss; der Welttest
verwendet ausdrücklich den echten Generator und das echte Terrain.

## Grenzen

- Keine Offline-Nachberechnung und keine Durstschäden. Der Vorrat sinkt nur
  bei lebenden Landtieren in der Kreaturenphase mit geladenem Boden und
  positiver Simulationszeit. Normale Szenenpause hält die KI an.
- Aquatische `swimmer` erhalten keine Ufersuche. Wasser wird durch einzelne
  Tiere nicht aus Seen oder Flüssen entfernt; die Hydrologie bleibt zuständig.
- Keine weltweite Wasserortung, globale Navigation oder Navigation auf
  Kugeloberflächen. Tiere ohne erreichbares Binnengewässer wandern weiter.
- Die Sozialkomponente ist über ihren öffentlichen Vertrag berücksichtigt.
  Der separat entwickelte Sozial-/Stammeszweig wurde nicht integriert.
- Eine Hungerschaden-, Durstschaden- oder Tierjagd-Simulation gehört nicht
  zu diesem Paket.

## Reproduzierbare Prüfung

```bash
python tools/validate_godot.py --godot /path/to/godot-4.6.3 \
  --project . --output /tmp/drinking-validation
```

`wildlife_drinking_test.gd` verwendet die echte Wildtierszene mit kontrolliertem
Gewässeradapter und echten Kollisionskörpern. Geprüft werden Annäherung,
Trinken, Beenden/Ruhe, Bodenkontakt, Entfernung und Höhe, Wand, überfluteter
Standplatz, ausgeladenes Wasserbett, verschwundenes Wasser, veränderter
Wasserstand, See/Fluss/Ozean, soziale Unterbrechung, Gefahr, Hungerpriorität,
kritischer Durst, ausbleibendes Wasser, eine sichtbare aber unerreichbare
Wasserstelle, alle Landrollen, Zeitstopp, Tod, Neustart in einem zweiten
Prozess, Laden im selben Prozess und Wiedererzeugung derselben Objekt-ID.
Die Prüfung vergleicht sämtliche Progressionsfelder in derselben
JSON-Darstellung, damit Integer-/Float-Normalisierung beim Laden nicht als
zusätzliche Belohnung fehlinterpretiert wird.

`wildlife_drinking_world_test.gd` lädt die normale Main-Szene an einem vom
echten Generator gelieferten höher gelegenen See. Die normale Tiererzeugung
wird für diese kontrollierte Anlaufprüfung angehalten. Ein Pflanzenfresser
muss über geladenes Terrain zum Ufer laufen, vom trockenen Boden trinken
und den Wasservorrat mit regulärem Speichern/Laden behalten. Die bisherigen
KI-, Nahrungssuche-, Wasser-, Heimgruppen- und Welttests bleiben Teil der
vollständigen Projektprüfung.
