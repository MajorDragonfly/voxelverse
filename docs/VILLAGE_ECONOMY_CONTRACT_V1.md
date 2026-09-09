# Dorfwirtschaft – Anschlussvertrag 1

Gültig für `economy.schema = 1` unter `tribe.schema = 3/4`, auf gemeinsamer Basis `3a3e027`. Implementierung: `world/tribe/village_economy.gd` und vorhandener `tribe_controller.gd`. Auftrag 5 besitzt ausschließlich Dorfbewohner, Arbeitsplätze, Aufträge, Vorräte und Transporte.

Die Erweiterung um Wohnraum und bis zu sechs Bewohner folgt [Wohnraumvertrag 1](VILLAGE_HOUSING_CONTRACT_V1.md). Der Milchvertrag bleibt identisch.

## Speicherung und Migration

Die Erweiterung liegt weiterhin unter `campaign.bodies[seed].tribe`. Globale Save-Version 6, Kampagnenversion, Körper-IDs und Art-IDs bleiben unverändert. `Tribe.upgrade()` erweitert validierte Stammesstände 1/2/3 auf 4, ohne Bewohner zu ersetzen, alte Vorräte/Quellen aufzufüllen, Fracht zu entfernen oder Aufträge neu zu vergeben. Ein alter Garten bleibt erhalten; aus Format 1 entsteht keiner. Neue Bewohnerfelder erhalten `hydration = 100`, `profession = none`, leeren `paused_order`/`task` und `blocked = false`. Neue Wasser-/Faser-/Milchvorräte beginnen bei null. Der alte Primärspielstand wird durch bloßes Laden nicht überschrieben.

Neue wirtschaftliche Unterstruktur `economy.schema = 1`:

| Feld | Bedeutung |
|---|---|
| `stations` | Gebaute Arbeitsplätze, Schlüssel well/forester/quarry/fiberbed; jeweils stabile Arbeitsplatz-ID und gespeicherte Position |
| `clocks`, `produced` | Spielzeittakt und kumulativ erzeugte Einheiten je Wasser/Holz/Stein/Fasern |
| `incoming` | Bereits erzeugte, noch abzuholende Milchlieferungen mit Restmenge und Position |
| `receipts` | Letzte bestätigte Milchlieferung je Quelle, höchstens 64 Quellen |
| `drinks`, `milk_meals`, `milk_received` | Kumulative tatsächliche Wasserverbräuche, Milchmahlzeiten und angenommene Milchmengen |

Neue `stock`-Schlüssel: `water`, `fiber`, `milk`; zusätzliche `deposits`: `water`, `fiber`. Bestehende Quellen wood/stone/food und ihre IDs bleiben bestehen. Jeder Ressourcentyp hat gemeinsam für alle Bewohner 48 Lagerplätze. Fracht zum Lager reserviert ihren Lagerplatz bereits bei der Abholung. Für Baustellen reservierte Fracht ist der Unterkunft zugeordnet und beansprucht keinen zweiten Lagerplatz. Angenommene, noch nicht abgeholte Milch reserviert ebenfalls Platz; sie zählt nicht als eingelagerte Nahrung.

Jede inkompatible Weiterentwicklung muss auch die äußere Stammesversion erhöhen. Der vorhandene Save-Service sperrt dann alte Leser vor einem stillen Rückgriff auf ältere Backups.

## Arbeitsplätze und Berufe

Voraussetzung ist das vorhandene Steinwerkzeug. Auf `Arbeitsplätze & Berufe` einen Arbeitsplatz wählen, anschließend einen freien Ort rechtsklicken. Kosten werden einmal aus dem gemeinsamen Lager reserviert. Dieselbe gespeicherte Baustelle kann von weiteren Bewohnern und Baumeistern fortgeführt werden.

| Arbeitsplatz | Kosten Holz/Stein | Quelle | Spielsekunden je neuer Einheit | Quellenkapazität |
|---|---:|---|---:|---:|
| Brunnen | 3 / 2 | Wasser | 5 | 8 |
| Forstplatz | 4 / 1 | Holz | 12 | 8 |
| Steinbruch | 4 / 2 | Stein | 15 | 8 |
| Faserbeet | 2 / 1 | Fasern | 12 | 8 |

Bei Forstplatz und Steinbruch bleibt noch vorhandenes Startmaterial erhalten, auch wenn mehr als acht Einheiten übrig sind. Neue Produktion beginnt unterhalb der Quellenkapazität. Produktion füllt nur die Quelle. Die eigentliche Einlagerung erfordert den Weg Quelle → Bewohner mit sichtbarer Fracht → Dorfplatz. Volle Quellen speichern keine beliebig großen Zeitrückstände. Pause, Laden und Abwesenheit erzeugen keinen Ertrag.

Freie Bauplätze benötigen einen zusammenhängenden trockenen Weg zum Dorf und zu den ausgewählten Bewohnern, eine ebene freie Fläche und Abstand zu anderen Quellen/Bauplätzen. Der bestehende örtliche Navigationsgraph umfasst ±12 Meter; Bauplätze liegen höchstens 16 Meter vom Anker entfernt. Arbeitsplätze lassen sich einmal je Typ bauen. Das ist keine unbegrenzt große Siedlung und kein freier Gebäudeeditor.

| Beruf | Dauerauftrag | gemeinsames Vorratsziel einschließlich Fracht |
|---|---|---:|
| Versorger | `provision`: Nahrung und Wasser nach Bedarf | 4 je Bewohner, mindestens je 12 |
| Holzarbeiter | `wood` | 16 |
| Steinmetz | `stone` | 16 |
| Fasersammler | `fiber` | 12 |
| Baumeister | `build`: aktuelle bezahlte Baustelle mitbauen | kein automatischer Kauf |
| Milchträger | `milk`: angenommene Lieferungen abholen | 12 |

Beruf und aktueller Befehl sind getrennt gespeichert. Manuelle Befehle erhalten den Beruf; „Beruf fortsetzen“ aktiviert dessen Zuständigkeit wieder. „Anhalten“ bewahrt Fracht, Arbeitsfortschritt, Bewegungsziel und vorherigen Befehl; „Fortsetzen“ nimmt diesen wieder auf. Essens-/Trinkpausen erhalten den Auftrag, Fracht wird vorher abgeliefert. Bei leeren Quellen und vollen Lagern bleibt die Zuständigkeit bestehen. Blockierte Wege werden ungefähr alle zwei Sekunden neu geprüft; es gibt keine Teleportation. Bewohner mit angehaltenem Auftrag bleiben angehalten, einschließlich ihrer Fracht.

Hunger sinkt um 0,08, Wasserversorgung um 0,06 Prozentpunkte je Spielsekunde. Arbeitende Bewohner versorgen sich unter 55 % am gemeinsamen Lager. Eine Mahlzeit erhöht die Sättigung um 25, eine Wassereinheit die Versorgung um 30 Punkte. Milch wird vor Wurzeln verzehrt, dabei genau eine Einheit aus demselben Lager abgebucht. Unter 20 % Hunger oder Wasser arbeiten/bewegen sich Bewohner langsamer. Bevölkerungszuwachs ist im Wohnraumvertrag beschrieben. Tod durch Mangel ist weiterhin nicht enthalten.

## D3: fertige Milchproduktion übergeben

Produktiver Aufruf nach geprüfter D1/D2/D3-Integration:

```gdscript
var accepted: bool = tribe_controller.receive_milk({
    "schema": 1,
    "source_id": animal_id,
    "body_id": current_body_id,
    "faction_id": owner_faction_id,
    "sequence": 1,
    "amount": 3,
    "position": [pickup_x, pickup_y, pickup_z]
})
```

Dieser Vertrag erzeugt keine Tiere, keine Milch durch bloßes Warten und keine Produktions-/Haltungsdaten. D3 liefert ausschließlich eine bereits abgeschlossene Produktion mit stabiler Tier-/Quell-ID. D3 muss zuvor am geprüften D2-Tier Besitz, Eignung, Betreuung, Futter und Wasser prüfen und Kosten einmal abrechnen. Die Dorfseite übernimmt keine Ersatzprüfung und keine zweite Zähmungslogik. Im aktuellen `main` fehlt dieser fertige Produzent; die Abnahme verwendet ausdrücklich eine getrennte D3-Prüflieferung.

Ablauf für den Produzenten:

1. Produktion und Kosten im gemeinsamen Kampagnensnapshot speichern; fertige Liefercharge bis zur Bestätigung behalten.
2. `receive_milk()` übergibt die Charge. Die Dorfseite validiert Körper/Besitzer, Reihenfolge, Menge, örtliche Position, Erreichbarkeit und Kapazität, speichert die Annahme atomar und bestätigt erst bei erfolgreichem Save.
3. Nur nach `true` entfernt D3 die bereits erzeugte Charge aus seiner Ausgangsliste. Sie darf dort danach nicht mehr verzehrt oder erneut produziert werden. Unterbrechung zwischen Dorfannahme und Produzentenbestätigung führt beim Neustart zum erneuten Senden genau derselben Charge.
4. Pro Quelle gilt genau die Folge 1, 2, 3 … . Nur die letzte identische Charge wird erneut mit `true` quittiert, ohne etwas hinzuzufügen. Keine zweite Charge senden, bevor die vorige bestätigt wurde. Gleiche Nummer mit geänderter Menge/Position, übersprungene Nummer, falscher Körper/Besitzer oder volles Lager werden abgelehnt.

Die Quittungen überleben Save/Load, auch wenn alle Milch abgeholt oder gegessen wurde. Eine schon bestätigte Charge wird auch dann erneut quittiert, wenn ihr ehemaliger Abholweg inzwischen nicht mehr erreichbar ist. JSON-Zahlen werden vor dem Quittungsvergleich normalisiert. Abholorte bleiben bei angenommenen Chargen fest; D3 darf das Tier danach bewegen, die bereits übergebene Milch liegt am vereinbarten Ort. Bei später blockiertem Weg wartet der Träger. Die API ist ein interner Anschluss für den vertrauenswürdigen D3-Controller, kein frei zugänglicher Import von Spielerangaben.

Milch wird am Abholort sichtbar, anschließend als Fracht getragen und erst bei Ankunft zum Vorrat. Es gibt keinen Lagerbonus durch die Annahme einer Charge. Die Kapazitätsprüfung umfasst offene Milch + Fracht + Vorrat; der Erhaltungscheck umfasst zusätzlich bereits verbrauchte Milch.

## Auftrag 6/7: vorhandene Ereignisse nutzen

Das bisherige Signal `order_resolved(order, command_id, accepted)` bleibt erhalten. Zusätzlich meldet der Dorfcontroller `community_event(kind, details)` nur tatsächliche Lieferungen, Mahlzeiten, Trinkvorgänge und fertige Bauten. Details enthalten `tribe_id`, bei Lieferungen/Mahlzeiten/Trinken einen kumulativen `sequence`-Zähler und Bewohner-/Ressourcenangaben. Konstruktion nennt `kind`, den aktuellen Hüttenstand und ab Stammesformat 4 eine stabile `building_id`. Neue Bewohner melden `resident_added` mit `member_id`, `tribe_id` und `population` erst nach erfolgreichem Save.

Fortschritt muss Ereignisse deduplizieren und im selben gemeinsamen Save-Kontext verbuchen: `(tribe_id, kind, sequence)` beziehungsweise `(tribe_id, construction, building_id)` für Gebäude (Format-3-Ereignisse nutzen weiterhin `kind, huts`). Keine Punkte beim Laden, bloßen Befehlen oder beim Anzeigen der Oberfläche vergeben. Die hierfür zuständige Fortschrittslogik wird von Auftrag 6 geliefert; diese Änderung vergibt keine Punkte und verändert keine fremde Art.
