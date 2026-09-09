# Auftrag 5 – Tierplatz, Tierpfleger und Milch

Stand: 9. September 2026. Branch `agent/d3-village-husbandry`, Ausgangspunkt `09b3b4621930bbe8008c6deca893beaabf5b7d1a` des veröffentlichten eigenen Dorfwachstums. Versorgung, Berufe, echte Bautransporte, Hütten/Zelte und Wachstum sind vorausgesetzt und in der Historie enthalten. Nur die beiden fertigen D1/D2-Vertragsdateien einschließlich ihrer UIDs wurden unverändert übernommen; Herkunft und Blob-Prüfung stehen im [D3-Vertrag](VILLAGE_HUSBANDRY_CONTRACT_V1.md). Keine fremden Laufzeitsysteme zusammengeführt. `ROADMAP.md` und die Integration nach `main` bleiben beim Integrationschat.

## Ergebnis

- Zwei frei platzierbare feste Tierplätze mit je einem Milchtier; Kosten vier Holz und zwei Fasern. Material wird aus dem gemeinsamen Lager reserviert und tatsächlich zur Baustelle getragen. Tierplätze erzeugen weder Schlafplätze noch Bewohner.
- Gespeicherter Beruf Tierpfleger und Dauerauftrag Tiere versorgen. Futter und Wasser reisen als sichtbare Fracht aus dem Lager zu den Trögen. Anhalten, Laden, Fortsetzen und Berufswechsel erhalten diese Fracht. Verschwindet das Tier, wird unterwegs befindliche Versorgung zurück ins Lager getragen.
- D1 bestimmt Eignung, Wasserbedarf, Milchmenge und Intervall. D2 bestimmt das konkrete lebende, gezähmte Tier, seinen Besitzer und seinen Aufenthalt. Ohne gültige Quelle, beim Weggehen/Folgen, Tod oder Besitzerwechsel pausiert die Produktion. D3 verändert diese Tierdaten nicht.
- Die Standard-D1-Milcheignung erzeugt nach 300 versorgten Spielsekunden zwei Liter Milch und verbraucht dabei ein Futter sowie vier Liter Wasser. Kleine Erträge sammeln sich ohne Aufrundung an; große Erträge warten auf Lagerkapazität und werden in Teilmengen angenommen.
- Milch wird am Tierplatz bereitgestellt und von den vorhandenen Milchträgern ins Lager gebracht. Produktion und Lieferquittung werden gemeinsam atomar gespeichert; ein Schreibfehler oder erneuter Aufruf vervielfacht keine Milch.
- Neue Ansicht Tierhaltung mit Tierplatz-/Tierauswahl, Beruf, Trögen und Produktionsstatus. Alle Aufträge bleiben über ihre Registerkarten und den Scrollbereich auch bei 800 × 900 erreichbar. Der Gebäudeeditor bleibt wie vereinbart für die Mittelalterphase vorgesehen.

**Integrationsgrenze:** Der vollständige Dorfablauf ist fertig. D2 war auf der geprüften Grundlage noch nicht Teil der normalen Stammeskampagne. Deshalb ist die gesamte Tierkette in einer ausdrücklich gekennzeichneten Prüfszene spielbar; der normale Dorfcontroller erzeugt kein Ersatztier. Der D2-/Integrationschat muss die vorhandene Kampagnenfauna und deren aktuellen gespeicherten Tierzustand an die drei dokumentierten lesenden Callables anschließen. Es gibt keine neue Arten- oder Zähmungslogik.

## Selbst spielen

1. `world/tribe/lab/husbandry_lab.tscn` in Godot öffnen und mit F6 starten. Die Szene heißt sichtbar „D3 · Tierhaltung – Prüfszene“ und verwendet einen eigenen Testspielstand `user://d3-village-lab/campaign.json` über den normalen Save-Service. Eine vorhandene Lab-Kampagne wird geladen, eine inkompatible Datei nicht überschrieben.
2. Beim ersten Start den vorhandenen Wechsel ins Stammeszeitalter bestätigen. Das kleine Testdorf erhält einen begrenzten früheren Materialvorrat, Werkzeug, Wurzelgarten, Brunnen und Faserbeet. Das gekennzeichnete D1/D2-Testtier steht bei `(0, 100.06, 7)`; es ist eine Testvoraussetzung, kein von D3 gezähmtes Tier.
3. Bewohner auswählen, unter Tierhaltung „Tierplatz setzen“ und mit Rechtsklick den Boden beim Testtier wählen. Die Bewohner tragen die sechs Materialeinheiten hin und bauen den Platz.
4. Das vorhandene Testtier zuordnen. Einen Bewohner als Tierpfleger, einen als Versorger und einen als Milchträger einsetzen. Die Berufe bleiben gespeichert. Nach der tatsächlich versorgten Produktionszeit wandert die Milch ins gemeinsame Lager.
5. Fracht mit „Anhalten“ stoppen, speichern/laden und „Fortsetzen“ verwenden. Die beiden Lab-Buttons oben speichern/laden denselben Kampagnenstand; es gibt keine getrennte Milchdatei. Für einen unabhängigen neuen Testlauf kann ein anderer `XDG_DATA_HOME` verwendet werden.

## Prüfungen und Nachweise

Godot 4.6.3. [Strukturierte Resultate](evidence/d3/results.json) und [Produktionsnachweis](evidence/d3/production.json) enthalten die Ergebnisse. Die Daten-/Laufzeitprüfungen erkennen auch Skriptfehler bei einem nominell erfolgreichen Prozessende. Warnungen bei absichtlich fehlgeschlagenen Schreibvorgängen sind erwartete Testfälle.

| Prüfung | Inhalt |
|---|---|
| D3-Vertrag | Schema-4-Migration mit bezahltem Zeltbau, Baufracht, Berufen, angehaltener Arbeit, Wachstum und vorhandener Milchquittung; zwei Tierplätze; keine Doppelzuordnung; ungültige Daten; Futterbilanzen; 300-s-Zyklus; Bruchteile einschließlich knapp unter einem Liter; 100-Liter-Ertrag in 48/48/4; Rückstau; wiederholte Quittung |
| Vollständiger D3-Lauf | echte UI-Platzierung; Baumaterialtransport und Save/Load; eigenes gültiges D2-Tier; Tierpfleger-/Versorger-/Milchträgerberufe; Futtertransport; Rücktransport ohne Quelle; Unterbrechungen durch Weggang, Folgen, Tod, Besitzer- und Rezeptwechsel; Pause; Laden im Zyklus; Schreibfehler beim Abschluss; reale Milchfracht und erneutes Laden |
| Separater Neustart | gleiche Tier-/Tierplatz-ID, Produktion und Bewohner; wieder angeschlossene lebende D1/D2-Testquelle; idempotente Quittung |
| Bestehendes Dorf | Wirtschafts-/Wohnraumverträge, Migration, bestätigter Übergang, Versorgung, vier Arbeitsplätze, Transport- und Auftragswiederaufnahme |
| Wachstum und Gelände | drei bis sechs Bewohner und Neustart; Bauen/Versorgung auf generiertem Terrain und erneuter Prozessstart |
| OpenGL/Mesa | neu geladener D3-Stand bei 1280 × 800 und 800 × 900, lesbare Tierpflege, einklappbare Steuerung, sichtbare Tröge und Testtier |

Im D3-Lauf kam exakt ein Standard-Milchzyklus mit zwei Litern im Lager an. Futter- und Wasserdaten, Rücklieferungen und angefangener nächster Zyklus stehen im Produktionsnachweis. D2s vollständiges Testregister blieb unverändert. Die reine Modellprüfung bestätigt zusätzlich, dass große und gebrochene D1-Erträge den Mengenvertrag einhalten.

Bildnachweise: [Tierhaltung](evidence/d3/husbandry-desktop.png), [schmales Fenster](evidence/d3/husbandry-narrow.png), [Tierplatz in der Welt](evidence/d3/husbandry-world.png).

```sh
# Vollständige Dorfprüfung einschließlich D3, je Testgruppe isolierte Spielstände:
python3 tools/check_village_economy.py --godot /pfad/zu/Godot_v4.6.3-stable_linux.x86_64

# Nur D3-Vertrag, spielbarer Ablauf und zugehöriger frischer Neustart:
python3 tools/check_village_economy.py --godot /pfad/zu/godot --skip-import --only tribal_age_husbandry_contract_test husbandry husbandry_restart
```

Die bisherigen UI-Prüfungen wurden an die dritte Registerkarte angepasst: Sie öffnen die betreffende Seite, scrollen das echte Steuerelement vollständig ins Sichtfeld und prüfen sowohl Fenster- als auch Scrollgrenzen. Unsichtbare Aktionen werden nicht mit einer sichtbaren Weltfläche verwechselt. Die tatsächlichen bisherigen Wirtschaftsabläufe bleiben Teil der Regression.

## Übergabe

Neue Produktionsmodule: `village_husbandry.gd`, `husbandry_source.gd`, `husbandry_runtime.gd`. Bestehender Dorfzustand, Steuerung, Bau-/Navigationsanschlüsse und HUD sind erweitert. `tribe.schema` steigt von 4 auf 5; äußeres Save-Schema bleibt 6. Alte Wirtschaft und Wohnräume werden nicht neu installiert. Der D3-Vertrag erläutert die gemeinsame Save-Transaktion und den lesenden D1/D2-Anschluss vollständig.

Vor dem Kampagneneinbau muss D2 geladene Tiere während der Stammesphase bereitstellen und mit seinem aktuellen Register am gemeinsamen Save teilnehmen. D3 wartet bei fehlender Quelle und erhält schon produzierte Milch. Abriss, Tierverkauf, neue Tierbedürfnis-/Gesundheitsregeln, Artengenerator, Zähmung, Reiten und Pflügen gehören nicht zu diesem Paket.
