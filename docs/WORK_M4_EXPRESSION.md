# M4-EXPRESSION – Tieremotionen und Begrüßung

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` auf
`agent/integration-vegetation-nest-20260915` (PR #110).
Fachbranch: `agent/m4-animal-expression-20260915`.
Nutzerauftrag: sichtbare Emotionen, Interaktionen und Ausdrücke bei Tieren.
ARCH-13/-24/-17/-27/-26 sind parallel belegt; dieses Paket ergänzt M4.

## Spielergebnis

- Wildtiere und aktive gezähmte Kampagnentiere nutzen zehn Ausdrucksprofile:
  ruhig, neugierig, zugewandt, verspielt, ängstlich, drohend, schmerzgeplagt,
  zufrieden, erschöpft und fressend/trinkend.
- Augen blinzeln und verändern ihre Öffnung; Kopf und Gesicht neigen sich und
  wenden sich begrenzt zum wahrgenommenen Ziel. Schwanzhaltung/-bewegung und
  Körperhaltung unterscheiden die Reaktionen. Individueller Seed variiert
  Ausdrucksstärke und Blinzelrhythmus, ohne den Generatorzustand anzufassen.
- Erfolgreiches Befreunden und Helfen löst Zuneigung aus. Nur erfolgreich
  angenommene Treffer lösen Schmerz aus. Gefahr unterbricht positive Gesten.
- Befreundetes Wildtier in der Kreaturenphase: nahe herangehen, ansehen und die
  konfigurierte **Interaktion** betätigen (Standard: **Linksklick**).
  Das Tier hält kurz inne, richtet seine Aufmerksamkeit auf den Spieler,
  reagiert verspielt und verwendet den vorhandenen Freundschaftslaut.
  Der vorhandene Sozialhinweis zeigt die aktuelle Taste auf DE/EN.
- Begrüßen setzt Freundschaft, lebende Beteiligte, freien Sichtkontakt und
  höchstens 3,6 m Abstand voraus. Drei Sekunden Abklingzeit; gesperrt bei
  Flucht/Drohen/Verfolgung, Pause, angehaltener Simulation und falscher Phase.
  Keine Punkte, Heilung, Futterkosten oder zusätzlichen Vertrauensgewinne.
- Gezähmte Tiere reagieren auf die vorhandenen Zustände Futterannahme, Angst,
  Verletzung und Nähe zum sichtbaren Betreuer beim Folgen. D2-Befehle und
  Produktions-/Versorgungsregeln bleiben beim bisherigen Besitzer.

## Anschluss

`CreatureExpressionDriver` beobachtet je aktivem Tier dessen lesenden
`get_expression_context()`-Port mit 5 Hz; er führt keine Welt-/Gruppensuche und
keinen Archivzugriff aus. Die Sozialkomponente aktualisiert ihre reine
Darstellungskopie der Beziehung beim ohnehin vorhandenen `entry()`-Lesen und
bei erfolgreichem Abschluss. Begrüßen prüft die maßgebliche Beziehung erneut.
`react_expression()`/`react()` akzeptieren nur die bekannten Präsentationsereignisse.

`CreatureEmotion` hält nur flüchtige Gewichte und eine Simulationsuhr. Schmerz
hat kurz Vorrang; Gefahr verwirft vorherige positive Gesten. Weiche Überblendung
mit festen Oszillatorfrequenzen verhindert Schwanzsprünge bei langen Laufzeiten.
Blinzeln und Ausdrucksvarianz sind für gleichen Seed und gleiche Timeline reproduzierbar.
Es gibt keine neuen Savefelder, Register, IDs oder Belohnungsereignisse.
Beim Laden, Tod und Entfernen werden vorübergehende Reaktionen verworfen.

Der Preview erhält die Pose optional. Editormodus/Spieleravatar sind ohne
explizite Tieranbindung neutral. `CreatureSculptMotion` setzt zuerst die
Originaltransformationen zurück, legt den Ausdruck auf und pflanzt **danach**
die Füße im vorhandenen lokalen/radialen Rahmen. Kieferaktionen bleiben beim
bestehenden Artikulationssystem. Keine neuen Rendernodes, Meshneubauten,
Kollisionsformen oder Änderungen an Körperanschlüssen während der Animation.

## Integration und Grenzen

Gemeinsame Anschlussdateien: RuntimePreview/SculptMotion (wenige Zeilen),
Wildtier-/Sozialskripte, `campaign_animal.gd`, drei Katalogmeldungen und die
Testregistry. Bei ARCH-24 die kleine optionale Pose-Anbindung erhalten;
Körperteildefinitionen und Revisionen werden hier nicht verändert. Bei Dorf-
und Tierpaketen den lesenden Actor-Port erhalten; keine Controller-/Save-
oder Wirtschaftsmodule aus diesem Paket zu übernehmen. Zentrale Projekt- und
Backlogseiten aktualisiert der Integrationschat.

Dies ist eine erste spielbare Ausdrucksschicht mit einer neuen Begrüßungsaktion.
Gegenseitiges Spielen zweier Tiere, differenzierte Ohren-/Lippenmuskeln,
Streicheln durch Stammesbewohner und dauerhafte emotionale Erinnerungen gehören
nicht zu dieser Lieferung. Kopfbewegung betrifft die vorhandenen Gesichtsmodule;
die Haut bekommt keine neue Skelettverformung. Zähmung bleibt Stammesfunktion.

Prüfung und Vorschau: [Nachweise](evidence/m4-expression/README.md).
