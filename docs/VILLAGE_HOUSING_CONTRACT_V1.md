# Stammeswohnraum und Dorfwachstum – Vertrag 1

Stand 9. September 2026. Fachbranch `agent/m6-village-growth`, aufgebaut auf dem veröffentlichten Versorgungsstand `a1b3d7c`. Lars' Vorgabe: In der Stammesphase feste Hütten- und Zeltmodelle; der Gebäudeeditor wird erst für die Mittelalterphase benötigt. Keine andere Facharbeit oder eigene Arten-, Tierhaltungs- oder Zähmungslogik.

## Spielbarer Ablauf

Unter Aufträge „Hütte setzen“ oder „Zelt setzen“ wählen und einen freien Bodenort rechtsklicken. Das HUD klappt während der Platzierung ein; Esc oder „Aufträge“ bricht sie ab. Steinwerkzeug ist erforderlich. Es gibt weiterhin genau eine gemeinsame Baustelle; weitere Bewohner oder Baumeister können mithelfen. Der Eingang zeigt bei beiden festen Modellen nach +Z. Kein Entwurfseditor, keine Rotation oder Abrissverwaltung in diesem Paket.

| Unterkunft | Kosten | Bauarbeit nach Materialanlieferung | Schlafplätze |
|---|---|---:|---:|
| Hütte | 6 Holz, 3 Stein | 20 Arbeitssekunden | 2 |
| Zelt | 3 Holz, 2 Fasern | 15 Arbeitssekunden | 1 |

Kosten werden erst nach Boden-, Platz- und Wegprüfung einmal aus dem gemeinsamen Lager reserviert und gespeichert. Bewohner holen einzelne reservierte Einheiten am Dorfplatz ab und tragen sie sichtbar zum Eingang. Arbeitsfortschritt beginnt erst nach vollständiger Anlieferung. Stoppen, neue Befehle, Pausen und Save/Load behalten die Zuordnung der Fracht zur Baustelle. Bei einem anderen Auftrag wird diese Fracht zuerst an die bezahlte Baustelle geliefert. Bei „Anhalten“ bleibt sie am Bewohner. Fertige Unterkünfte können nicht erneut bezahlt werden; ein erneuter Hütten-/Zeltauftrag beginnt eine weitere Unterkunft.

Höchstens sechs Unterkünfte und sechs Bewohner. Neue Flächen liegen im vorhandenen Graphen von ±12 Metern, maximal 16 Meter vom Dorfanker entfernt. Das gesamte Fundament und der Eingang müssen trockenen, ausreichend ebenen Boden besitzen. Fundamente und Zugänge bestehender Unterkünfte, Quellen und offene Milchabholungen bleiben erreichbar. Neue Fundamente dürfen auch keine Bewohner oder gespeicherten Bewegungsziele einschließen. Bauflächen sind bereits während des Baus für die Wegsuche reserviert. Fertige Gebäude haben echte Wände, einen offenen Eingang und Dachkollision. Steht ein Bewohner aus einem alten Spielstand in einer früher rein dekorativen Hüttenwand, bleibt seine Position erhalten. Er verlässt sie über den Eingang; die neue Kollision wird erst danach zugeschaltet. Rohstoffanzeigen werden unabhängig davon aktualisiert; ihre Aktualisierung zerstört keine Gebäudekollision.

## Wachstum

Ein weiterer Bewohner kommt nach 90 ununterbrochenen Spielsekunden hinzu, wenn:

- ein fertiger zusätzlicher Schlafplatz frei ist;
- Wurzelgarten und Brunnen gebaut sind;
- je `2 × (Bevölkerung + 1)` Nahrung und Wasser tatsächlich im Lager liegen;
- alle Bewohner mindestens 50 % Sättigung und Wasserversorgung besitzen.

Unterbrochene Versorgung setzt diesen Takt zurück. Pause und Offlinezeit zählen nicht; Laden setzt den gespeicherten Takt fort. Am Ende muss ein freier, erreichbarer Eingang mit geladenem Boden zur Verfügung stehen. Für den neuen Bewohner werden genau zwei Nahrung und zwei Wasser aus dem Lager verwendet. Neue Mitglieder werden erst nach erfolgreicher atomarer Speicherung sichtbar angelegt. Ein fehlgeschlagener Save stellt Bewohnerliste und Vorräte wieder her. Der nächste Versuch erfolgt frühestens fünf Spielsekunden später.

Neue Mitglieder gehören derselben gespeicherten Art und Fraktion an und verwenden die vorhandene Kreaturendarstellung. Die ursprüngliche Kreatur und ihre zwei Gefährten bleiben die ersten drei Einträge mit identischen IDs; die ursprüngliche Nestgruppe bleibt unverändert. Neue Mitglieder beginnen ohne Beruf und wartend. Ihre Karten, Auswahl, Gruppenbefehle, Berufe, Arbeitsfortschritte und Fracht nutzen dieselben Abläufe wie die ursprünglichen drei.

Versorger halten vier Nahrung und vier Wasser je Bewohner bereit, bei sechs Bewohnern also je 24. Die Lagerkapazität bleibt 48 je Ressource. Arbeitende Bewohner machen bereits unter 55 % eine Essens-/Trinkpause, damit sie bei guter Versorgung oberhalb der Wachstumsschwelle bleiben. Andere Berufsvorratsziele bleiben erhalten. Milch bleibt Nahrung für die bestehenden Mahlzeiten; die anfängliche Versorgung eines neuen Bewohners verwendet Wurzeln und Wasser.

## Gemeinsamer Save

`tribe.schema` steigt auf 4; äußere Save-Version bleibt 6. `economy.schema` und der D3-Milchvertrag bleiben 1. Die Wohnraumerweiterung liegt im bisherigen Dorf, nicht in einem zweiten Speicher.

| Feld | Bedeutung |
|---|---|
| `housing.schema` | 1 |
| `housing.homes` | Fertige Unterkünfte mit stabiler `id`, `kind`, `position`, `entrance` |
| `housing.clock` | Bereits erfüllte Spielsekunden für den nächsten Bewohner, 0–90 |
| `members[].species_id`, `faction_id` | Müssen der Art und Fraktion dieses Dorfes entsprechen |
| `members[].construction_id` | Leerer String oder ID der Baustelle, zu der die getragene Ressource gehört |
| `project.id`, `position`, `entrance` | Reservierte Unterkunft und fester Zugang |
| `project.materials` | Bereits bezahlte, noch am Dorfplatz abzuholende Einheiten |
| `project.delivered_materials` | Tatsächlich am Eingang abgelieferte Einheiten |

`huts` bleibt als Zahl fertiger Hütten erhalten; Zelte werden dort nicht mitgezählt. Wohnraum wird aus `housing.homes` berechnet. Die zwei alten `sites` bleiben unverändert als Migrationsdaten erhalten, reservieren aber keine unbebauten Flächen mehr. Neue Unterkunfts-IDs sind `Ids.scoped("shelter", tribe.id, index)`, zusätzliche Bewohner-IDs `Ids.scoped("resident", tribe.id, index)` mit den stabilen Listenindizes 3–5. Es gibt keine Löschung oder Wiederverwendung dieser Indizes.

Format 1/2 erhält zuerst die bisherige Wirtschaftserweiterung. Bei Format 3 wird die vorhandene Wirtschaft ausdrücklich **nicht neu installiert**: Arbeitsplätze, Takte, Berufe, Milchchargen, Quittungen, Mengen und Aufträge bleiben vollständig erhalten. Vorhandene Hütten werden an ihren alten Plätzen übernommen. Eine angefangene alte Hütte behält ihren Baufortschritt; die bereits nach altem Verfahren bezahlten Materialien gelten als angeliefert. Keine neuen Schlafplätze, Bewohner oder Rohstoffvorräte entstehen durch die Migration. Das bloße Lesen überschreibt keine alte Datei.

Validierung prüft stabile Identitäten, eigene Art/Fraktion, Einwohner- und Gebäudegrenzen, Eingänge, Berufe, Fracht und alle Materialmengen. Je Bausorte gilt `reserviert + unterwegs + angeliefert = Kosten`. Die reservierte Gesamtmenge zählt zur Materialerhaltung, aber nicht erneut gegen die Lagerkapazität. Unvollständige Materialanlieferung erlaubt keinen positiven Baufortschritt. Künftige Dorfversionen werden über den bestehenden Save-Service gesperrt.

## Anschlüsse und Prüfung

`community_event("construction", details)` ergänzt `building_id`, damit mehrere Zelte bei unverändertem Hüttenstand eindeutig bleiben. `resident_added` nennt `member_id`, `tribe_id`, `population`; Auftrag 6 besitzt weiterhin jede Punktevergabe. Auftrag 7 kann die vorhandenen Status-/Auftragssignale verwenden. Es wird keine Nachricht an andere Fachchats gesendet und nichts nach `main` zusammengeführt.

D3 behält [Wirtschaftsvertrag 1](VILLAGE_ECONOMY_CONTRACT_V1.md). Ein neuer Bewohner kann Milchträger werden und akzeptierte Chargen wirklich abholen. Auch nach Wachstum und Save/Load quittiert eine identische Wiederholung nur die bereits angenommene Lieferung. Tierproduktion selbst bleibt bei D3.

Tests: `tribal_age_housing_recovery_test.gd` prüft alte Bewohner in Hüttenwänden, geschützte D3-Abholorte sowie fehlgeschlagene und erneut versuchte Wachstumssaves. `tribal_age_growth_contract_test.gd` prüft Migration, Materialerhaltung und Bevölkerungsgrenzen. `tribal_age_growth_test.gd` prüft echte Bautransporte, Stop/Resume, Save/Load, Kollision, Eingänge, 3→6 Bewohner, Berufe und D3-Transporte; `--restart-check` verwendet einen frischen Prozess. `tribal_age_world_test.gd -- --economy --housing` ergänzt Hüttenbau und weitere Transporte auf generiertem Terrain. Der gemeinsame Runner `tools/check_village_economy.py` führt diese und die vorhandenen Regressionstests mit getrennten Speicherständen aus.
