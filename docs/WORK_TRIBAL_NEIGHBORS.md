# Auftrag 6 – erste aktive Nachbarfraktion

Stand: 9. September 2026. Fachbranch `agent/tribal-neighbors`.

Bewusste Ausgangsbasis ist das in diesem Chat abgeschlossene und veröffentlichte
Paket aus Stammesfortschritt und fertig übernommener M6-Dorfwirtschaft:
lokaler Übergabecommit `dbec2781db269bba04ded93e8729573de15b31cc`, auf GitHub
`ff841110690a6a98d1d37b22bbdab541c9207d66`. Beide haben denselben Dateibaum
`b7a34757040338e90da6317848765eae8de1bab2`. Gemeinsamer ursprünglicher main-Stand
ist `3a3e0272375e556f3ff65b7370582af79a9d48b5`. Keine weiteren Fachstände übernommen;
`ROADMAP.md` bleibt beim Integrationschat. Es erfolgt kein automatischer Main-Merge.

## Ergebnis

Ein erreichbarer Uferbund mit zwei eigenständigen Bewohnern derselben eigenen
Spezies ist spielbar. Seine Lager-, Bewohner-, Technik- und Fraktionsdaten bleiben
von der eigenen Dreiergruppe getrennt. Die vorhandene Dorfleiste bietet Suche,
Hilfsauftrag und Kamerablick auf beide Lager.

Mindestens zwei eigene Bewohner tragen tatsächlich sechs Nahrung und vier Holz
vom eigenen Lager zu den Nachbarn. Deren Bewohner bauen anschließend ihre
Unterkunft. Die Fraktion wird freundlich; der abgeschlossene Gemeinschaftserfolg
verdient einmal drei eigene Stammespunkte. Insgesamt sind jetzt maximal 27 soziale
Stammespunkte erreichbar. Die Nachbarvoraussetzung wird im Entwicklungspfad als
erfüllt angezeigt, ohne Mittelalter oder Neuzeit freizuschalten.

Anhalten erhält Fracht. Neue Befehle bringen übrige Hilfsfracht zuerst heim, ohne
Sammelverdienst oder Materialkopie. Vorübergehende Hindernisse behalten den Auftrag;
eine freie Route wird wieder aufgenommen. Leere Vorräte halten die Abholung an,
sechs Nahrung bleiben als Heimreserve. Pro Träger höchstens fünf Einheiten sorgt
für echte Beteiligung mindestens zweier Bewohner.

## Dateien und Integration

| Bereich | Änderung |
|---|---|
| Neue Module | `world/tribe/neighbors/neighbor_state.gd`, `neighbor_runtime.gd`, `ui/tribe/neighbor_panel.gd` samt UIDs |
| Dorfcontroller | Kleiner Anschluss für Nachbarziele, Warenarbeit und aktive Zeit; gemeinsame Bewegung mit optionalem Bewohnerdatensatz; reservierter Lagerplatz |
| Gemeinsame Navigation | Für Nachbarlager begrenzt 18 statt 12 Meter; Halbmeter-Zwischenpunkte ergänzen geprüfte Einmeter-Stufenübergänge; nächster freier Lagerplatz in 6–16 Metern; gespeicherter Ortsbereich bleibt 22 Meter |
| Bestehende Dorfleiste | Ein weiterer Tab, vorhandener Stil und Pausezustand |
| Fortschritt | Einmaliger Nachbarverdienst, gespeicherte Fraktions-/Vereinbarungsquittung, produktiver Serviceanschluss |
| Speicherung | Optionaler Körperdatensatz validiert; Warenbilanz, Verdienste und Zukunftsschutz gegen denselben Kampagnensnapshot geprüft |
| Epochenvertrag | Nachbarhilfe spielbar; Gruppenkonflikt bleibt als spätere Alternative geplant, beide Folgephasen bleiben gesperrt |
| Tests | Neuer Vertrags-, Weltablauf- und generierter Planetentest; kleiner Erweiterungspunkt im vorhandenen Planetentest; Wirtschaftsmigration prüft die aktuelle Stammesversion |

Der vollständige Vertrag und die spielbare Anleitung stehen in
`TRIBAL_NEIGHBOR_CONTRACT.md`. Äußeres Save-Format 6, Fortschrittsformat 5 und
Dorfformat 3 bleiben erhalten; `tribal.schema` steigt 2 → 3, das neue optionale
`body.tribal_neighbor.schema` ist 1. So schützen auch vorherige Leser das neue
Gesamtpaket vor Überschreiben. Alte Wirtschaftsbeweise und alle Käufe bleiben
erhalten, es werden keine Nachbarerfolge nachträglich erfunden.

## Prüfung und Übergabe

Geprüfter Implementierungscommit: `0b94bba2772c62a35c04e4ad5efd366ee8360a99`.
Dieser Bericht und `validation/tribal-neighbors.json` folgen als eigener
Dokumentationscommit. Godot 4.6.3, isolierte Testspielstände, **12/12 Prüfungen
bestanden**. Die JSON-Datei enthält die letzten Ergebnisse der beiden
Abschlussläufe und die tatsächlichen Waren-/Bauquittungen.

| Prüfung | Ergebnis |
|---|---|
| Editorimport und Assetquellen | 2/2 bestanden |
| Nachbarvertrag, GUI-/Physikablauf und erzeugter Planet | 3/3 bestanden |
| Stammesfortschritt und Wirtschaftsfortschritt, jeweils Vertrag und Weltablauf | 4/4 bestanden |
| Skilltree, Entwicklungspfad und Speicherplätze | 3/3 bestanden |

Im Nachbar-Weltablauf: sieben Nahrung abgeholt, eine zurückgegeben, sechs
angekommen; vier Holz angekommen und einmal verbaut; drei Träger mit 3/3/4
Einheiten; zwei Nachbarbauer; zwölf aktive Bausekunden; exakt drei eigene
Stammespunkte. Der Planetentest bestätigt zusätzlich dieselbe vollständige
Lieferung aus wirklich gesammelten Ressourcen. `git diff --check` ist sauber.

Die Weltprüfung benutzt den tatsächlichen bestätigten Stammesstart, reale
GUI-Aktionen, physische Träger und Nachbarbewohner, einen vorübergehend blockierten
Weg, Rückgabe nach geändertem Auftrag, Save/Load mitten in Fracht und Bau sowie
zwei separate Neustartprozesse. Die Nachbarleiste wird auch bei 800×900 auf
Bedienflächen innerhalb des Viewports geprüft. Ein gespeicherter fremder
Tierdatensatz bleibt ausdrücklich eine Erhaltungs-Fixture.

Der zusätzliche Planetentest verwendet den regulär erzeugten Planeten mit Seed
15838, echte Rohstoffquellen und die vorhandene Bodenkollision. Er gründet einen
Heimatplatz, bestätigt den Stammesstart, sammelt Holz und Nahrung, liefert die Hilfe,
lässt beide Nachbarn bauen und lädt dieselben Gruppen wieder. Die ersten
Geländeläufe deckten eine zu grobe Wegsuche auf. Halbmeterschritte ergänzen nun
die weiterhin nötigen Einmeter-Stufenübergänge. Vier gespeicherte Bodenauflagen
tragen die Unterkunft auch auf kleinen Geländestufen. Es wird weder Gelände
eingeebnet noch Fracht zum Ziel teleportiert. Die fertige Lieferung ist auf dem
erzeugten Gelände nachgewiesen; eine erfolgreiche Kontaktsuche ist nicht auf
jedem geografisch eingeschlossenen Heimatplatz garantiert.

Keine neue Windows-Version oder Ziel-PC-Leistungsmessung; keine neue gerenderte
Bildabnahme. Der gemeinsame manuelle Spieltest bleibt Teil der Integration.

## Verbleibender Umfang

Ein lokales Lager und ein endlicher Hilfsauftrag, noch keine Vollwirtschaft der
Nachbarn, Fernreisen, wiederkehrender Handel, Krieg oder Bevölkerungswachstum.
Künftige Fraktionsentwicklung darf nur die betreffende Gesellschaft verändern.
Fremde Wildarten bleiben Tiere. Der nächste Ausbau kann eine echte Gegenlieferung
mit begrenztem Warentausch auf den geprüften Transportvertrag setzen.
