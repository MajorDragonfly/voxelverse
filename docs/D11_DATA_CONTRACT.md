# D1.1 – anatomische Nachweise und Habitat-Wiederaufnahme

Aufbauend auf D1 Schema 1 und dem abgeschlossenen Körpervertrag B1 Schema 1.
Arten-Generator `domestic_fauna_v1`, Art-IDs und äußere Speicherschemata bleiben
erhalten. Neue Felder sind optionale, separat versionierte Erweiterungen.

## Anatomischer Nachweis

`fauna_catalog.species[].body_evidence` enthält Schema 1, die Prüfregel
`domestic_body_v1`, `source_sha256`, `status` (`passed` / `rejected`), `errors`
sowie B1-Deskriptor `body` und B1-Ruhemessung `rest`. Der Hash bindet den
Nachweis an den vollständigen eingefrorenen Bauplan nach JSON-Normalisierung.
Fehlt der Nachweis, bedeutet das ungeprüft. Ein vorhandener Nachweis wird beim
Laden weder ersetzt noch durch eine neue Körpererzeugung repariert.

Die Prüfung baut die echte Kreaturenlaufzeit auf einer lokalen Ruheebene auf.
Alle Rollen benötigen mindestens vier reale Beinrigs mit unterschiedlichen
Fußkennungen, höchstens 0,002 Entwurfseinheiten Kontaktfehler und eine
Stützfläche um die Mitte der Voxelhaut. Mindeststützweite: 25 % der Hautbreite;
Mindeststützlänge: 30 % der Hautlänge. Die maximale Ruhelängendehnung beträgt
1,20 beim Zug-/Reittier und 1,35 bei den anderen beiden Rollen. Das Arbeitstier
benötigt `saddle.primary`, `harness.left`, `harness.right` außerhalb der Haut.
Die fachliche Eignung besitzt weiterhin D1; B1 liefert die Messdaten.

Die Prüfung läuft einmal je ungeprüfter Art am frisch aufgebauten ersten
Exemplar, vor seiner Aufnahme in den aktiven Tierbestand und vor dem ersten
Simulationstick. Sie verwendet dessen vorhandenes Beinrig; es wird kein
zweiter Tierkörper für die Prüfung gebaut. Gemessene Ablehnungen werden gespeichert und
spawnen nicht als bestätigte Pflichtart. Bereits vorhandene Arten, Namen,
Körper, Beziehungen und IDs bleiben auch bei einer Ablehnung erhalten.
Fehlende B1-Anschlüsse in alten Bauplänen werden ausschließlich lesend mit den
deterministischen B1-Altstandparametern geprüft. Sie werden nicht in den
gespeicherten Entwurf geschrieben.

Der B1-Aufruf `BodyContract.describe(blueprint, skin = null)` erhält dazu einen
optionalen Mesh-Parameter. Er verhält sich wie der bereits bestehende zweite
Parameter von `resolve`: Das Mesh muss genau zu diesem Bauplan gehören.
Bestehende Aufrufe und sämtliche B1-Datenfelder bleiben kompatibel.

Eine Ruheprüfung bestätigt weder anatomische Belastbarkeit unter realer Last
noch die Kollisionsfreiheit eines vollständigen Reiters/Geschirrs. Diese
erweiterte Passungsprüfung bleibt beim Kreaturenpaket und D4.

## Wiederaufnahme einer fehlgeschlagenen Habitatsuche

`fauna_catalog.habitat_recovery` speichert Schema 1, Algorithmus
`domestic_habitat_recovery_v1`, den deterministischen Startpunkt, den bereits
nachgewiesenen Zugangsweg `prefix`, besuchte
Rasterpunkte mit Elternbezug und Routenkosten, den nächsten Knoten und dessen
nächste Richtung sowie den Status `searching`, `ready` oder `blocked`.

Die zusätzliche Suche beginnt nur, wenn die bisherige Radialsuche weniger
als drei Pflichtrollen erreicht. Sie prüft kurze Geländewege im Raster,
erreicht dadurch auch Standorte hinter Geländeumwegen und setzt nach Laden
an genau derselben Kante fort. Vorhandene Vorkommen samt Objektkennungen,
Todeszuständen und Ersatzzeitpunkten bleiben bestehen; neue Vorkommen werden
ergänzt. Ursprungswahl, Reihenfolge und neue Habitatkennungen hängen nicht
von Bildrate, Besuchsreihenfolge oder Spielerbewegung ab.

Auch die Ersatzsuche darf kein trockenes Gelände oder freie Wege erfinden.
Ein erschöpfter Suchraum bleibt als `blocked` nachweisbar; es erfolgt keine
Endlossuche pro Frame. Konkrete Suchgrenzen und Abnahmewerte werden im
Übergabebericht festgehalten.

Suchgrenzen: 4-m-Raster, höchstens 16.384 besuchte Punkte und 1.024 m Abstand
vom Suchursprung; höchstens 4.095 Wegschritte und insgesamt 192 Wasserschritte
einschließlich eines vorhandenen Zugangswegs. Die Laufzeit verarbeitet bis zu
16 Kanten pro Aktualisierung und unterbricht nach ungefähr 2 ms zwischen
vollständigen Kanten. Schmale Übergänge unterhalb der Rasterweite und komplett
unzugängliches Terrain können weiterhin `blocked` ergeben. Bei einem bereits
erreichbaren Vorkommen beginnt die ergänzende Suche dort, mit dem vorhandenen
Weg als Präfix. Es gibt keine zufällige Verlegung bestehender Populationen.

## Speicherregeln

Ungültige Daten werden abgelehnt; unbekannte Nachweis-, B1-Anschluss- oder
Suchversionen sperren Laden und Überschreiben vor dem Rückgriff auf ältere
Backups. Fehlende Erweiterungen in D1-Altständen sind zulässig. Die
Anschlussfelder ändern weder Zähmvertrauen noch Besitzer oder Bürgerstatus.
