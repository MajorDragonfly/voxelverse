# ARCH-26-CONSTRUCTION-CONTROL

Feste Basis: `d57b1ef385728728b132518a1ea05683888dcae0` aus Spieltest-PR #125.
Paketbesitzer: dieser Fachchat; eigener Branch `agent/arch26-construction-control-20260916`.
Atmosphere Detail, Weather 02, M4 Social Play und ARCH-30 bleiben bei ihren Besitzern.

## Spielen

Im Stammesmodus unter **Aufträge** erscheint zur laufenden Baustelle eine eigene
Verwaltung. Sie zeigt Baufortschritt, zugeordnete/gestoppte Bewohner und je Rohstoff
reservierte, getragene und angelieferte Mengen. Die Auswahl lässt sich zur Baustelle
schicken; eine eigene Baustellenpause bleibt dabei bestehen.

**Bau pausieren** stoppt weitere Abholungen und Bauarbeit. Bereits getragene
Baumaterialien dürfen noch ankommen. Andere Berufe und die Versorgung der Bewohner
laufen weiter. **Bau fortsetzen** setzt die bestehende Baustelle fort; inzwischen
anderweitig beauftragte Bewohner werden nicht zurückgeholt.

**Bau abbrechen …** verlangt eine zweite, ausdrückliche Bestätigung. Der bisherige
Baufortschritt wird aufgegeben. Noch im Lager reserviertes Material wird sofort
freigegeben. Bereits angelieferte und getragene Einheiten bleiben dagegen an ihrem
Ort: Zugewiesene Bewohner holen sie ab und tragen sie zurück. Die Baustelle bleibt
bis zur letzten Rückgabe belegt. Manuell gestoppte Träger müssen fortgesetzt oder
weitere Bewohner zugewiesen werden. Fehlende Wege erzeugen keine Ankunft.

Die volle Rückgabemenge benötigt freien Lagerraum, einschließlich normaler Ladungen
und zugesagter Lagertransporte. Bei fehlendem Platz wird der gesamte Abbruch
unverändert abgelehnt. Nach angenommenem Abbruch wird der benötigte Raum bis zur
realen Rückgabe reserviert. Es gibt keine Lieferpunkte, Berufsbelege oder fertigen
Gebäude für zurückgeholtes Baumaterial. Bestehende Werkzeug-/Gartenprojekte ohne
Materialtransport werden bei Abbruch nach ihrem bisherigen Kostenvertrag direkt
zurückgebucht.

## Vertrag

- Weiterhin ein Projekt pro Ort, höchstens zwei Siedlungen und sechs Bewohner je
  Körper. Keine parallele Bau-, Transport- oder Speicherarchitektur.
- Wirtschaftsformat **4**. Formate 1–3 werden weiterhin gelesen; Migration 3→4
  ändert nur die Versionsmarke. Bewohner, Quellen, Takte, Gebäude, Fracht und alte
  angefangene Projekte bleiben erhalten. Ältere Builds schützen diese Stände über
  ihren bereits vorhandenen Wirtschaftsversionscheck vor Laden/Überschreiben.
- Optionales `project.control`: `schema=1`, Zustand `active`, `paused` oder
  `recovering`. Ohne Feld gilt das bisherige aktive Verhalten. Beim Rückbau enthält
  `refunded` die bereits zurückgebuchten Einheiten. Pro Ressource bleibt die Summe
  aus reserviert, angeliefert, getragen und zurückgebucht genau gleich den Baukosten.
- Neue Bauaufträge haben eine eigene `attempt_id`, unabhängig von der künftigen
  Gebäude-/Arbeitsplatzkennung. Abgebrochene Versuche zählen nicht als Mitwirkung
  an einem späteren Neubau; doppelte Fortschrittsbeobachtung bleibt wirkungslos.
- Der Dorfcontroller speichert Pause/Fortsetzen/Abbruch mit dem gemeinsamen
  SaveGameService und vollständigem Rollback bei Schreibfehlern. Nah und fern
  verwenden dieselben angekommenen Arbeitsschritte. Pause und geschlossenes Spiel
  erzeugen weder Bauarbeit noch Materialrückgabe.
- `project.control` und unbekannte Versionen werden im alten Einzelort und in der
  Siedlungssammlung geprüft. Kein Rückfall auf ein altes Backup für Zukunftsdaten.

## Anschluss und Abnahme

Die additive UI ist ein eigenes Panel; im bisherigen Dorfpanel werden nur Aufbau
und Aktualisierung ergänzt. Neue Texte werden im gemeinsamen DE/EN-Katalog geführt.
Kleine geteilte Anschlüsse: Dorfcontroller/Arbeit/Wirtschaft/Wohnraum, bestehende
Speicherteilnehmer und Siedlungsvalidierung, Fortschrittsbeobachtung und Testregister.
Bei der Integration diese Anschlüsse mit anderen Änderungen an denselben Dateien
zusammenführen. Zentrale Statusseiten und Roadmap-Häkchen bleiben beim Integrationschat.

Die beiden neuen Tests sind genau einmal dem Vertrag `village` zugeordnet.
Prüfstände, korrigierte Erstbefunde und Rohprotokolle stehen unter
`docs/evidence/arch26-construction-control/`.
Native Windows-/Grafik-/Ziel-PC-Freigabe und gemeinsame Vollsuite gehören zur
Integration. Die Layoutmatrix prüft Bedienbarkeit headless, keine gerenderte Optik.
