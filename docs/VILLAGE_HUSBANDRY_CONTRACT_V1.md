# D3 – Tierplätze, Versorgung und Milch

Stand: 9. September 2026. Aufbau auf M6-Dorfwirtschaft und Wohnraum. `tribe.schema = 5`, `husbandry.schema = 1`; äußeres Save-Schema bleibt 6. D1 und D2 werden gelesen, weder erweitert noch überschrieben.

## Zuständigkeit und Stand des Anschlusses

D3 besitzt Tierplätze, transportierte Futter-/Wasservorräte und Produktionsnachweise. D1 bestimmt die Milcheignung und Rezeptwerte; D2 besitzt individuelle Tier-ID, Art, Körperbezug, Besitzer, Gesundheit, Zähmung und Bewegung. Ein Tier wird kein Bewohner. D2s reservierte Felder `cargo` und `equipment` bleiben leer.

Der Dorfablauf ist implementiert. Die normale Kampagne muss ihre D2-Tiere noch durch den zuständigen Integrations-/D2-Chat anschließen. Bis dahin verbindet die ausdrücklich benannte Szene `world/tribe/lab/husbandry_lab.tscn` den echten Dorfcontroller mit einer isolierten D1/D2-Testquelle. Die Dorfsteuerung selbst erzeugt keine Tiere und enthält keine Zähmregeln.

Nur folgende fertige, unveränderte Vertragsdateien wurden übernommen; keine fremden Laufzeitsysteme oder Branches zusammengeführt:

| Quelle | Commit | Unveränderte Datei | Git-Blob |
|---|---|---|---|
| D1 | `bb43b61482ab129b72a66b5299a6bfec80a1e128` | `world/fauna/domestication/domestication_contract.gd` | `f83e60acb507a76dbbcade4a64659b55d072623d` |
| D2 | `75abefa2a15e7b6dffaafb840e3199489c3cc296` | `world/domestication/animal_state.gd` | `a1f0dd027e6bf51dc7c4a5aba49193ab35a92d3f` |

Die jeweils zugehörige `.gd.uid` ist ebenfalls unverändert. Beim Zusammenführen können diese identischen Dateien dedupliziert werden. D1-Vertrag und D2-Register bleiben jeweils Schema 1.

## Host-API

Der Host registriert drei lesende Callables am vorhandenen Dorfcontroller:

```gdscript
tribe.husbandry.configure(read_current_d2_registry, read_d1_traits, find_live_d2_actor)
```

| Callable | Eingabe | Rückgabe |
|---|---|---|
| `read_current_d2_registry` | keine | aktuelles, durch D2 validierbares Register dieser Kampagne und dieses Körpers |
| `read_d1_traits` | `species_id: String` | durch den originalen D1-Vertrag validierbare Eignung dieser Art |
| `find_live_d2_actor` | `object_id: String` | vorhandener sichtbarer `Node3D` dieses konkreten D2-Tieres oder `null` |

Die Callables müssen nach jedem Laden den aktuellen gemeinsamen Kampagnenstand lesen und aktuelle Akteure auflösen. Keine beim Registrieren eingefrorenen Kopien, zweite Speicherdatei, neue Tier-ID oder D3-Ersatztier verwenden. Der Host muss D2s Register, D1-Körperbezüge und D3-Dorfzustand im selben Kampagnensnapshot checkpointen; die Lab-Szene demonstriert dies mit dem ausdrücklich markierten Feld `body.d3_lab_sources`. Dieses Testfeld ist kein vorgeschlagener produktiver D2-Speicherort.

`tribe.husbandry.assign(pen_id, animal_id)` und `release(pen_id)` speichern die Zuordnung atomar. `candidates()` liefert nur vorhandene, lebende, eigene, gezähmte fremdartige Milchtiere mit Pflanzenfutter-Eignung. Die Zuordnung prüft zusätzlich den tatsächlichen Aufenthalt am gewählten Tierplatz. D2 bewegt das Tier dorthin; D3 teleportiert es nicht.

Vor Versorgung und Produktionsfortschritt werden geprüft: gültiger D1-Vertrag mit Rollenwert `milk` und Ernährung `plant`; gültiges D2-Register mit identischer Kampagnen-/Körper-ID; `tamed`, eigener Besitzer, fremde Art; sichtbarer Akteur im Szenenbaum höchstens 0,5 m von D2s gespeicherter Position entfernt; unveränderter Art-/Entwurfs-/Rezeptbezug; `wait` oder `home`, höchstens 1,8 m vom Tierplatz entfernt; geladener trockener Boden und erreichbarer Eingang. Fehlende Quelle, Besitzerwechsel, Tod, Folgeauftrag, Weggang oder geänderter Körper pausieren den Fortschritt. D3 verändert D2s Hunger-/Durstwerte nicht und implementiert keine zweite Tiergesundheit; die hier berechnete Versorgung ist Voraussetzung der D3-Produktion.

## Tierplatz und Transporte

Höchstens zwei feste, offene Tierplätze, je ein zugeordnetes Tier. Ein Platz kostet vier eingelagerte Holz und zwei Fasern sowie 15 Arbeitssekunden mit dem vorhandenen Arbeitsfaktor; Steinwerkzeug erforderlich. Die vorhandene einzelne Dorfbaustelle reserviert Kosten einmal. Bewohner holen die reservierten Einheiten am Lager ab und tragen sie zum Zugang. Erst nach vollständiger Anlieferung beginnt der Bau. Die Identität lautet `Ids.scoped("pen", tribe.id, index)`; Zugang ist `position + (0, 0, 2)`.

Freie Platzierung prüft Bodenfläche, Quellen, Bewohner, bestehende Gebäude und Zugänge sowie ausstehende Milchabholorte. Der fertige Platz ist offen begehbar; sichtbare Pfosten und Tröge sind kein geschlossenes Gehege. Tierplätze erzeugen keine Schlafplätze. Unterkünfte und Arbeitsplätze dürfen bestehende Tierplätze und ihre Zugänge nicht überbauen.

Beruf `keeper` / Tierpfleger erteilt den Dauerauftrag `tend`. Futter und Wasser werden ausschließlich aus dem gemeinsamen Lager entnommen: eine Einheit pro tatsächlichem Transport. `member.care_pen_id` bindet diese Fracht an den Platz; `construction_id` muss leer bleiben. Stop/Resume, Berufswechsel und Save/Load behalten die Fracht. Fehlt die gültige Tierquelle bei Ankunft, trägt der Bewohner die Einheit zum Lager zurück. Unterwegs befindliches Tierfutter reserviert deshalb weiterhin seinen Lagerplatz. Blockierte Wege warten auf die bestehende Neuprüfung.

| Vorrat | Kapazität pro Tierplatz | Auffüllen unterhalb (einschließlich Fracht) |
|---|---:|---:|
| Pflanzenfutter (`food`) | 4 Portionen | 2 Portionen |
| Wasser (`water`) | 8 Liter | 4 Liter |

Die Transporte erfolgen in ganzen Einheiten und dürfen die Auffüllschwelle deshalb um weniger als eine Einheit überschreiten; die Kapazität bleibt verbindlich. Versorger halten die Lagerbestände aufrecht. Tierpfleger priorisieren Wasser vor Futter und berücksichtigen gleichzeitig unterwegs befindliche Einheiten anderer Pfleger. Milchträger bleiben der vorhandene Beruf `milk_carrier`.

## Zeit, Mengen und gemeinsame Milchannahme

Nur aktive Simulationszeit zählt, maximal 0,25 s pro Produktionsschritt. Kein Fortschritt während Pause, Entladen oder durch vergangene Wanduhrzeit. Pro 300 versorgten Spielsekunden wird eine Portion Pflanzenfutter und D1s `water_need` in Litern verbraucht. Fortschritt reicht jeweils nur so weit wie beide tatsächlichen Tröge. Bei fehlender Versorgung bleibt die angefangene Uhr erhalten. Die Standard-D1-Milcheignung ergibt zwei Liter nach 300 versorgten Sekunden bei einem Futter und vier Litern Wasser.

Das D1-Rezept gilt unverändert: `milk_interval` 1–86400 s, `milk_yield` und `water_need` jeweils größer null bis 100. Lager und Transporte verwenden ganze Liter. Bruchteile sammeln sich über die Anzahl abgeschlossener Intervalle an: Gesamtproduktion `floor(cycles * milk_yield)`; keine Aufrundung pro Intervall. Pro Tier bleibt höchstens ein fertiger Produktionszyklus als `pending_milk` zurück. Bei Rückstau wird weiter versorgt, aber kein weiterer Zyklus angehäuft.

Der vorhandene Milchvertrag aus `VILLAGE_ECONOMY_CONTRACT_V1.md` bleibt unverändert. Tier-ID ist `source_id`; Sequenzen beginnen mit 1 und steigen je angenommener Teilmenge. Große D1-Erträge werden nach freiem Lagerplatz in höchstens 48 Liter große Lieferungen geteilt. Angenommene Milch liegt zunächst am gespeicherten Abholpunkt, nicht im Lager. Erst reale Milchträger liefern sie ein; die bestehenden Essenspausen können sie danach verbrauchen.

Produktionsabschluss, `pending_milk`, Dorf-Inbox, Quittung und Sequenz werden durch **denselben** erfolgreichen `SaveGameService.save_now()` gespeichert. Bei Schreibfehler wird die gesamte Änderung dieses Produktionsschritts zurückgesetzt und nach fünf Spielsekunden erneut versucht. Ohne erfolgreichen Save entsteht keine anerkannte Lieferung. Erneute identische Quittungen ändern auch nach JSON-Roundtrip und Prozessneustart nichts. Bereits produzierte Milch bleibt abholbar, wenn ihr Tier später fehlt oder stirbt; ihr Abholpunkt bleibt erhalten.

## Gespeicherte Daten und Migration

`husbandry` enthält `pens`, `records` sowie die Bilanzen `withdrawn`, `returned`, `delivered` und `consumed` jeweils für Futter und Wasser. Ein Platz enthält `id`, `kind: pen`, `position`, `entrance`, `animal_id`, `food`, `water`. Ein Produktionsnachweis pro Tier enthält ausschließlich `species_id`, `design_ref`, `recipe`, `clock`, `cycles`, `produced`, `pending_milk`, `handed_over`, `sequence` und `pickup`; keine kopierten Besitzer-, Zähm-, Bewegungs- oder Gesundheitszustände.

Ein Tier darf nur einem Platz zugeordnet sein. Auflösen benötigt keine noch unterwegs befindliche Versorgung und keinen unangenommenen Milchrest. Bereits anerkannte Abhollieferungen behalten ihren Ort. Die bis zu 32 Produktionsnachweise bleiben nach Auflösen erhalten, damit erneutes Zuordnen keine Sequenz zurücksetzt. Eine Tier-ID mit bereits anderweitig belegter Milchquittung wird nicht als neuer D3-Produzent übernommen. Die bestehende maximale Quittungsanzahl von 64 bleibt bestehen.

Validierung prüft Identitäten, Kapazitäten, Reservierungen, endliche Mengen, Rohstoffbudgets einschließlich verbrauchter Tiernahrung, Produktionsmengen und Quittungsfolge. Entnommen = zurückgebracht + abgeliefert + unterwegs; abgeliefert = verbraucht + Tröge. Abgeschlossene und angefangene Produktionszeit muss durch mindestens den entsprechenden Futter-/Wasserverbrauch gedeckt sein. Produktion = unangenommen + angenommen. Fehlerhafte neue Daten werden abgelehnt, nicht repariert oder aufgefüllt.

Schema 4 erhält nur leere Tierhaltung und `care_pen_id: ""` an vorhandenen Bewohnern. Wohnraum, Wachstum, Wirtschaft, bezahlte Baustellen, Baufracht, Aufträge und bisherige Milchquittungen bleiben unverändert. Schema 1–3 durchläuft zuvor die vorhandenen Migrationen. Neue Bewohner erhalten das neue Transportfeld. Der bereits vorhandene Schutz gegen zukünftige `tribe.schema` verhindert, dass ältere Dorfprogramme diesen neuen Stand still zurückschreiben.
