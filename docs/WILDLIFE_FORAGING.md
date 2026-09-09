# Hunger und pflanzliche Nahrung

Dieses Paket baut ausschließlich auf dem abgeschlossenen Wildtier-KI-Paket
`agent/wildlife-ai` auf. Es führt keinen anderen Arbeitszweig zusammen.

## Spielablauf

- `grazer`, `forager` und `climber` besitzen Sättigung von 0 bis 100. Der
  Anfangswert variiert deterministisch zwischen 35 und 85. Aktive Tiere verlieren
  0,12 Punkte je Simulationssekunde; unter 45 suchen sie bis mindestens 75 weiter.
- Sichtbare Beerenbüsche im Umkreis von 16 Metern können als Ziel dienen.
  Bestehende Kollisions-, Abbruch- und Wasserprüfungen steuern den Weg.
  Gefahr unterbricht das Fressen, soziale Aufmerksamkeit hält das Tier an.
  Unzugängliche Ziele werden nach ausbleibendem Fortschritt vorübergehend verworfen.
- Fressen benötigt Nähe, geringe Höhendifferenz, Boden und freie Sicht. Alle
  0,8 Simulationssekunden gehen höchstens 10 Nahrungspunkte aus dem Busch ins Tier.
  Nach Sättigung ruht es sechs Sekunden und nimmt sein übliches Herdenverhalten auf.
- Spieler und Tiere teilen sich dieselben 30 Nahrungspunkte eines Busches.
  Leere Büsche verlieren sichtbar ihre Beeren. 180 Kampagnensekunden nach dem
  letzten Bissen wächst der Vorrat vollständig nach, auch bei Teilverbrauch.
- Die vorhandenen Zustandsanzeigen ergänzen „Sucht Nahrung“ und „Frisst“.
  Die Inspektionsschnittstelle liefert zusätzlich `satiety`.

Im normalen Terrain deaktiviert die bestehende V3-Chunk-Basis die alten
interaktiven Beerenbüsche. Deshalb ergänzt ein eigener `PlantFoodStreamer` am
Nest begrenzt echte Nahrungspflanzen neben der dekorativen Vegetation. Er wartet
auf die initialisierte Spielwelt, platziert höchstens zwei Büsche pro Durchlauf
und insgesamt höchstens 32. Kandidaten sind an Weltseed und Rasterzelle gebunden;
Platzierung benötigt trockenes, ausreichend flaches, geladenes Kollisionsgelände.
Das Versetzen des Nests versetzt keine bereits platzierten Pflanzen.

## Speicherung und Grenzen

Die Erweiterung liegt unter
`campaign.bodies[str(int(seed))].wildlife_foraging` mit eigenem Schema 1.
Vorhandene Kampagnenleser erhalten die komplette `bodies`-Struktur. Globale
Speicherversion, Begegnungsbuch und Progression werden nicht geändert.

- `animals[object_id]`: Sättigung und Suchbedarf. Die Identität kommt unverändert
  aus `get_campaign_identity()` des jeweiligen Wildtiers.
- `plants[berry:x:z]`: verbleibende Nahrung und Kampagnenzeit für Regeneration.
  Die Position ist auf Zentimeter gerundet und durch den Körperdatensatz begrenzt.
- Normales Speichern erfasst die aktuellen Werte zusammen mit dem übrigen Spiel.
  Laden bindet lebende Tiere neu an den geladenen Datensatz und erstellt die
  sichtbaren Futterstellen erneut. Es gibt weder eine zweite Speicherdatei noch
  einen Schreibvorgang pro Bissen.
- Unbekannte Erweiterungsversionen und fehlerhafte Einträge bleiben unverändert.
  Betroffene Nahrung beziehungsweise Bedürfnisse werden nicht weitergeschrieben.
  Beide Tabellen sind auf jeweils 32.768 Einträge begrenzt; bei voller Tabelle
  werden neue Einträge blockiert, bestehende werden nicht heimlich gelöscht.
- Keine Offline-Nachberechnung. Hunger läuft nur bei lebenden Pflanzenfressern
  mit geladenem Boden in der Kreaturenphase und bei positiver Simulationszeit.
  Ausgeladene Individuen behalten ihren letzten Wert. Ein neues Individuum mit
  neuer Objekt-ID hat eigene Bedürfnisse. Dieses Paket übernimmt nicht die
  Individuenplatzierung oder Identitätsvergabe des Fauna-Streamers; der laufende
  Sozialzweig besitzt dessen weiterführende Habitat-Identitäten.
- Bisher keine Hungerschäden, Durst, Fleischsuche, Jagd zwischen Tieren oder
  weltweite Wegsuche. Die regionale Biomasse ist weiterhin eine abstrakte
  Hintergrundsimulation; einzelne Bissen erzeugen keine Populationsereignisse.

## Anschlüsse an andere Arbeiten

`foraging_brain.gd` erweitert unsere bestehende `wildlife_brain.gd`, die wiederum
V8 erbt. Editor, Renderer, V7/V8, Sozialkomponente, Skilltree, Forschungsziele,
Geländegenerator und Fauna-Streamer bleiben in ihren eigenen Zweigen.
`SocialBehavior.controls_movement()` und `entry()` werden über den bestehenden
KI-Anschluss berücksichtigt; ein Vertragstest ersetzt keine Gesamtintegration
des noch getrennten Sozialzweigs.

Bestehende Einstiegsszenen ändern nur den Wildtier-Skriptpfad, den
Beerenbusch-Skriptpfad und den neuen Kindknoten am Nest. Die gemeinsame
Sichtprüfung setzt die vollständige RID-Ausschlussliste auf einmal: Godots
`query.exclude` liefert beim Lesen eine Kopie, sodass ein bloßes `append()`
den Zielbusch zuvor nicht zuverlässig vom Sichtstrahl ausschloss.

## Prüfung

```bash
python tools/validate_godot.py --godot /path/to/godot-4.6.3 \
  --project . --output /tmp/foraging-validation
```

`wildlife_foraging_test.gd` prüft echte Wildtier- und Beerenbuschszenen auf
physische Annäherung, portioniertes Fressen, Sättigung, Ruhe, gemeinsamen
Spielervorrat, Neustart in einem separaten Prozess, Laden im selben Prozess,
Reinstanziierung, Regeneration, soziale Unterbrechung, Flucht, Sichtbarrieren,
Distanz/Höhe, gestoppte Simulationszeit, konkurrierende Verbraucher, Abbrüche,
unbekannte Daten und getrennte Kampagnen.

`wildlife_foraging_world_test.gd` verwendet die normale Main-Szene mit tatsächlichem
Terrain und Nahrungspflanzen aus dem neuen Streamer. Ein kontrolliert platzierter
Pflanzenfresser muss physisch einen dieser Büsche erreichen und Nahrung entnehmen.
Danach werden Sättigung und Teilvorrat über reguläres Speichern/Laden geprüft.
Die vorhandenen Wildtier- und Heimgruppentests prüfen parallel deren normalen
Spielablauf; keine dieser Prüfungen behauptet eine Integration fremder Zweige.
