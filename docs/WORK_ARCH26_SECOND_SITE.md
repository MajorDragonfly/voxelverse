# ARCH-26-SECOND-SITE: produktiver zweiter Siedlungsort

Basis: `d378ca0ecd7f03429a5150df6358e0646ec06689` (main nach #92).
Fachbranch: `agent/arch26-second-site-20260915`.

## Spielablauf

Im Stammesdorf einen Gefährten ohne laufende Bindung oder Fracht auswählen und
per Rechtsklick 14–18 m vom Dorfplatz entfernen. Nach seiner tatsächlichen
Ankunft unter **Siedlungen → Außenlager am Standort des Gründers errichten**
gründen. Der neue Standort muss trockenen, geladenen Boden, sichere lokale Wege
und fünf freie Arbeits-/Bauplätze bieten. Ein ungeeigneter Standort wird erklärt
und verändert den bisherigen Zustand nicht.

Im selben Reiter lassen sich Heimatdorf und Außenlager verwalten. Jeder Ort
besitzt eigene Lager, Bewohner, Ressourcen, Arbeitsplätze und Bauaufträge.
Bewohner oder Waren werden beim Ansichtswechsel nicht versetzt. Ein Ort wird
physisch simuliert, der andere über zertifizierte Wege vereinfacht. Alte Hütten
und neue Baustellen behalten ihre Besitzer. Bauen über fremden Arbeitsstellen
oder bereits zertifizierten Transportwegen wird abgewiesen.

## Speichervertrag und Anschlüsse

- Bei der ersten Gründung kopiert der bestehende Vertrag `body.tribe` und
  `body.village_simulation` verlustfrei in `body.settlements`, Schema 1.
  Bisherige Einzelorte behalten bis dahin ihr bestehendes Format.
- Das registrierte Feld enthält höchstens zwei Einträge. Der ursprüngliche
  Siedlungsname/ID, Bewohner, Aufträge, Fracht, Produktionszähler und Wege bleiben
  erhalten. Der neue Ort übernimmt genau einen vorhandenen, bereits angekommenen
  Gefährten. Lager, Werkzeuge und Gebäude werden nicht verschenkt.
- Die Auswahl ist gespeichert. Gründung/Ansichtswechsel schreiben über den
  gemeinsamen SaveGameService. Bei Fehlern werden Zustand und ggf. beobachteter
  Fortschritt zurückgesetzt, bevor die bisherige Ansicht weiterläuft.
- Work-/Simulationsadapter teilen ausschließlich den jeweiligen Dorfzustand.
  Sie werden nicht gespeichert; Körpererweiterungen bleiben beim Originalkörper.
  Ein als Körper gespeicherter Adapter wird explizit abgewiesen.
- Zwei Zeitcursor im vorhandenen Scheduler, weiterhin höchstens 32 Schritte bzw.
  kooperatives 2-ms-Budget. Der eigene Spieler arbeitet am unbeobachteten Heimatort
  nur, solange er auf demselben Körper ist. Bei Rückkehr werden alle Ortsschulden
  vor der Ankunft mit abwesendem Spieler abgearbeitet. Pause/geschlossene App
  produzieren nichts.
- Insgesamt weiterhin höchstens sechs Bewohner je Körper; Wachstum vergibt freie
  ursprüngliche Bewohner-IDs über beide Orte hinweg. Kein verdoppeltes Budget.
- Fortschritt bleibt ortsbezogen, Epochenvoraussetzungen am ursprünglichen Dorf.
  Bestehende Nachbarhilfe bleibt beim Heimatdorf. Tierhalter werden über alle
  Orte validiert; Tiere eines unbeobachteten Orts laufen nicht auf fremden Wegen.
- Mini-/Weltkarte erhalten den neuen Ort. Die neue Bedienung nutzt den vorhandenen
  DE/EN-Dienst und erhält Controls/Auswahl beim Sprachwechsel.

## Fachprüfung

Neue Tests sind einmal unter `village` in `tools/validation/contracts.json`
registriert:

- `settlement_runtime_test`: echter Kugelstart, bestätigter Stammesübergang,
  physisch gelaufener Gründer, zwei Orte, getrennte Lieferungen, gehaltene Fracht,
  fehlgeschlagener Auswahl-Save, Nah/Fern, Pause und neuer Prozess.
- `settlement_save_test`: echte SaveGameService-Snapshots mit zwei gleichzeitigen
  Bauaufträgen und je einer gehaltenen Materialeinheit; ungültige Gründungen,
  globales Bewohnerbudget, Schreibfehler, Rückkehr-Zeitcursor und Fortsetzung
  beider Bauten nach Neustart. Geometrie hier ausdrücklich synthetisch.

Der bestehende `settlement_collection_test` bleibt unverändert als Nachweis für
Identitäts-, Produktions- und Reservierungsgrenzen erhalten. Betroffene
Altverbraucher werden gezielt geprüft; Befehle, Quellstand und Ergebnisse stehen
in der PR-Übergabe und den Prüfnachweisen.

Die lokale Ausführungsrichtlinie untersagt den Unix-Socket des virtuellen
Bildschirms; die angefragte Eskalation wurde automatisch abgelehnt.
`tools/review_settlements.py` führt deshalb die reproduzierbare Grafikprüfung in
`Settlement gameplay render` aus: echter Spielablauf, sechs Aufnahmen in DE/EN,
800×600, 1280×720 und 1920×1080 mit Software-OpenGL. Der CI-Bericht ist erst nach
seinem erfolgreichen Lauf ein Nachweis.

## Integrationshinweise und Grenzen

Geteilte Anschlüsse: SaveGameService/Teilnehmer, Fortschrittsleser, Dorfcontroller,
Tierhaltung, Siedlungsausschlüsse, Kartenmarker, PO-Katalog und Testregistry.
Mit #98 die beiden getrennten Ergänzungen in ProgressionService erhalten; mit
#95 den kleinen `add_settlements`-Anschluss in der Dorfübersicht erhalten. #97
ändert zusätzlich die Kartenknoten in `spherical_campaign.gd`.

Die Integration aktualisiert PROJECT_STATUS/NEXT_PARALLEL_WORK/Backlog einmal
für den gemeinsamen Stand. ARCH-26 insgesamt bleibt offen: mehrere gleichartige
Arbeitsplätze innerhalb *eines* Ortes, ferne Gründung, Bewohnerumzüge und größere
Ortszahlen sind nicht Bestandteil dieser Lieferung. Regionale Transporte
zwischen Lagern gehören ARCH-27. Kein Windows-Export, kein Langzeit- oder
Ziel-PC-/60-FPS-Nachweis.
