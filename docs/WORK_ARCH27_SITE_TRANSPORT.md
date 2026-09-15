# ARCH-27-SITE-TRANSPORT: Waren zwischen zwei Ortslagern

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`, Integrationsbranch
`agent/integration-vegetation-nest-20260915` (PR #110).
Fachbranch: `agent/arch27-site-transport-20260915`.

## Bedienung

Im verwalteten Ausgangsort einen freien Gefährten direkt zum Lagerplatz bewegen.
Er muss ohne Ladung und weitere Bindung warten. Unter **Siedlungen → Warentransport**
Ressource und Menge wählen und mit dem ausgewählten Bewohner versenden. Das Ziel
ist der jeweils andere eigene Ort. Ein Auftrag trägt eine bis vier Einheiten;
auf einem Körper läuft höchstens ein Auftrag. Die eigene Kreatur bleibt verfügbar.

Holz, Stein, Nahrung, Wasser, Fasern, Milch und Eier verwenden denselben Ablauf.
Die Ware verlässt beim reservierten Auftrag den verfügbaren Ausgangsbestand.
Ziellager und Ausgangslager halten Platz für Ankunft bzw. mögliche Rückgabe frei.
Der Ausgangsort zeigt einen physischen Träger samt Fracht; bei Verwaltung des
anderen Orts oder einer Planetenreise übernimmt der vorhandene Fernscheduler.

**Abbrechen / Ware zurückbringen** gibt einen noch nicht abgeholten Auftrag frei.
Unterwegs wird am nächsten zertifizierten Wegpunkt umgekehrt. Eine gesperrte
Rückroute lässt Ware und Bindung bestehen. Gutgeschrieben wird ausschließlich am
angekommenen Ziel. Die Rückkehr erfolgt zum Ausgangslager. Nach Lieferung bleibt
der Bewohner an seiner tatsächlichen Position und gehört weiterhin zum Quellort;
er wird weder dupliziert noch automatisch in das andere Dorf versetzt.

## Daten und Laufzeit

- Optionaler registrierter Körperbaustein `site_transport`, Schema 1, im bestehenden
  SaveGameService. Eine sequenzierte Auftrags-ID, dessen Regionaltransportdaten,
  der zertifizierte gerichtete Graph und eine Rückkehranforderung. Kein eigener Save.
- Die bestehenden Dörfer führen `economy.freight`: kumulative Import-/Exportzähler
  und reservierte Kapazitäten pro Ressourcen-ID. Ware befindet sich genau einmal
  im verfügbaren Lager oder im Auftrag. Reservierte Kapazität ist keine Ware.
- Über beide Orte gilt Export minus Import gleich der noch gebundenen Ladung.
  Die üblichen Quellen-, Produktions-, Eier- und Tierfutterbilanzen bleiben wirksam
  und berücksichtigen nur tatsächliche Ein-/Ausfuhren. Bereits fertige Transporte
  vergeben keine neuen Sammel- oder Produktionsbelohnungen.
- Ein freier vorhandener Bewohner bleibt der einzige Träger. Reguläre Dorfaufträge,
  Nachbarhilfe, Zähmangebote und Fernarbeit dürfen dieselbe Identität nicht zugleich
  übernehmen. Die gemessene Gesamtgrenze von sechs Bewohnern bleibt bestehen.
- Vorhandene RegionalTransport-Reducer steuern Reservierung, Abholung, Wegpunkte,
  Blockierung, Rückkehr und Abschluss. Der synchrone Adapter bucht Abschluss und
  beide Lager gemeinsam; veraltete Vorschläge und wiederholter Abschluss scheitern.
- Nahfortschritt benötigt physische Ankunft. Ferne Schritte verbrauchen höchstens
  0,25 aktive Kampagnensekunden auf dem gespeicherten Weg, mit konservativem Fußtempo.
  Übergaben innerhalb eines Segments prüfen die beobachtete Lage im Wegkorridor.
- Fehlendes Netz, gesperrte Verbindung oder geänderte Revision suspendieren.
  Sperrzeit wird nicht beim Wiederöffnen nachgeholt. Der Warenempfang wartet auf
  den Zeitcursor des Zielorts; rückständige Arbeit darf keine zukünftige Ware nutzen.
- Neue Gebäude halten aktive Frachtkorridore frei. Ortswechsel und Körperreise
  übergeben den bestehenden Auftrag und holen ausschließlich bereits entstandene
  Spielzeit nach. Pause und geschlossenes Spiel erzeugen keine Lieferungen.
- Direkte Bedienbefehle verwenden den gemeinsamen Save mit Rücksetzung bei Fehlern.
  Laufende Schritte gehören zum nächsten gemeinsamen Snapshot. Unbekannte zukünftige
  Auftrags-, Routen-, Ressourcen- oder Bilanzversionen bleiben schreibgeschützt.

## Integration und Grenzen

Mit ARCH-26-WORKPLACE-INSTANCES nacheinander integrieren. Gemeinsame Stellen:
Dorfcontroller, Siedlungswechsel, Wirtschaft/Tierhaltung, Fernscheduler und
Save-Teilnehmer/Reisekette. Die kleinen Träger-Sperren im Nachbar-/Zähmungsadapter
und die zwei neuen Einträge unter `village` in `tools/validation/contracts.json`
erhalten. Sprachkatalog nach `SITE_FREIGHT_*`-Schlüsseln zusammenführen. Keine
Änderung der reservierten ARCH-13/-24/-17-Implementierungen. Zentrale Statusseiten
und Roadmap aktualisiert der Integrationschat nach Übernahme.

Diese Lieferung verbindet die zwei vorhandenen nahe gelegenen Orte. Sie bietet
keine neuen Siedlungen, Fernwegesuche, Fahrzeuge oder größere Einwohnerzahlen.
Der Graph bleibt begrenzt; ein nicht mehr bestätigbarer Weg hält den Auftrag an.
Grafischer Ziel-PC-Test, Windows-Export und FPS-Abnahme bleiben Aufgaben der
Integration. Fachnachweise werden unter `docs/evidence/arch27-site-transport/`
mit tatsächlichem Quellstand und Befehlen abgelegt.
