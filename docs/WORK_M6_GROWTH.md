# Auftrag 5 – Hütten, Zelte und Dorfwachstum

Stand: 9. September 2026. Branch `agent/m6-village-growth`, Ausgangscommit `a1b3d7cad8e2ec4661675d14b6e59974b27141fe` des veröffentlichten Versorgungsbranches `agent/m6-village-economy`. Keine anderen Fachbranches übernommen. Für die Integration auf `main` wird der vorausgehende Versorgungsstand benötigt; er ist in der Branchhistorie enthalten. `ROADMAP.md` bleibt beim Integrationschat.

Lars hat den Ausbau um freie Unterkünfte und bis zu sechs Bewohner bestätigt. Seine Ergänzung ist umgesetzt: feste Hütten und Zelte in der Stammesphase; Gebäudeeditor erst für die Mittelalterphase. Die bestehende Erlaubnis zur Veröffentlichung der fertigen eigenen Arbeit wird fortgeführt. Es erfolgt keine automatische Zusammenführung nach `main`.

## Ergebnis

- Hütten und Zelte lassen sich über die Auftragsbuttons frei platzieren. Ganze Bodenflächen, Bewohnerpositionen, Quellen, bestehende Eingänge und offene Milchabholorte werden geprüft. Ungültige Plätze oder fehlgeschlagene Saves kosten keine Vorräte.
- Baumaterial wird aus gemeinsamem Vorrat einmal reserviert, vom Dorfplatz abgeholt und zur Baustelle getragen. Erst vollständige Anlieferung erlaubt Baufortschritt. Stop/Resume, Berufswechsel und Save/Load behalten Material, Ziel und bezahlte Arbeit.
- Feste Modelle mit offenen Eingängen, Wänden und Dachkollision; die Wegsuche führt um die Gebäude. Rohstoffaktualisierungen erzeugen die Kollision nicht neu. Alte Bewohner innerhalb ehemals dekorativer Hütten werden nicht versetzt: Sie können herauslaufen, bevor die neue Wandkollision aktiv wird.
- Nach jeweils 90 Spielsekunden ausreichender Versorgung wächst der Stamm von drei auf höchstens sechs Mitglieder. Zusätzlicher fertiger Wohnraum, Garten, Brunnen, eingelagerte Reserven und versorgte Bewohner sind erforderlich. Zwei Nahrung und zwei Wasser werden pro neuem Bewohner genau einmal verwendet. Ein fehlgeschlagener Save erzeugt weder Bewohner noch Verbrauch.
- Die ursprünglichen drei IDs und die Nestgruppe bleiben erhalten. Neue Bewohner gehören derselben Art und Fraktion an, lassen sich auswählen, Berufen zuweisen und gemeinsam befehligen. Versorger halten vier Nahrung und vier Wasser je Bewohner bereit. Essens-/Trinkpausen setzen bei 55 % ein, damit zuverlässige Versorgung oberhalb der 50-%-Wachstumsschwelle bleibt.
- Der D3-Milchanschluss bleibt identisch. Auch der sechste Bewohner kann akzeptierte Milch tatsächlich abholen. Wiederholte Lieferquittungen bleiben nach Wachstum und Neustart idempotent.
- Das HUD zeigt alle Bewohner, scrollt längere Auftragslisten und lässt sich einklappen. Auf schmalen Fenstern stehen zwei Karten nebeneinander. Die Gebäudeplatzierung legt die Welt automatisch frei.

Vollständiger Speicher-/Anschlussvertrag: [VILLAGE_HOUSING_CONTRACT_V1.md](VILLAGE_HOUSING_CONTRACT_V1.md). `tribe.schema = 4`, äußeres Save-Schema weiter 6. Schema 3 behält seine Wirtschaft unverändert; Schema 1/2 erhält die bisherigen Ergänzungen vor der Wohnraummigration. Der Text im vorhandenen Save-Service ist der einzige dortige Änderungsbereich.

`community_event("construction", ...)` enthält nun eine stabile `building_id`, damit mehrere Zelte eindeutig bleiben. `resident_added` wird erst nach erfolgreichem Save mit der neuen `member_id` gemeldet. Fortschritts- oder Artenlogik wird dadurch nicht ersetzt.

## Prüfung

Godot 4.6.3, gezielte Daten- und Laufzeitprüfungen ohne Skript-/Parserfehler. Fehlerwarnungen wurden ausschließlich dort erwartet, wo Tests absichtlich einen Schreibfehler oder eine inkompatible Save-Version erzeugen.

| Prüfung | Ergebnis |
|---|---|
| Wirtschaftsdatenvertrag | bestanden; D3-Sequenzen, Kapazität und Ressourcenregeln erhalten |
| Wohnraumdatenvertrag | bestanden; echte Format-3-Migration einschließlich Beruf, Fracht, Baufortschritt und D3-Quittungen; Material- und Bevölkerungsschutz |
| Bisheriger Stammestest | bestanden; bestätigter Wechsel, Auswahl einschließlich Umschalt/Rahmen, Transporte, Werkzeug, zwei frei platzierte Hütten, Zukunftsschutz |
| Bisherige Versorgung | bestanden; echte Format-1-Migration, Garten, dauerhafte Nahrung und gespeicherte Essenspause |
| Bisheriger Wirtschaftslauf | bestanden; Arbeitsplätze, Berufe, Stopp/Fortsetzen, Wasser, blockierte Wege und D3 |
| Neuer Hütten-/Wachstumslauf | bestanden; physischer Baumaterialtransport, Baufracht-Save/Load, Wände/Eingang, zwei Hütten und zwei Zelte, 3→6 Bewohner, neue Berufe und Milchtransport |
| Separater Prozess mit sechs Bewohnern | bestanden; derselbe gespeicherte Stand, vollständige Akteure/Karten und fortsetzbare Berufe |
| Migrations- und Schreibfehlerfälle | bestanden; alter Bewohner in Hüttenwand läuft ohne Teleport heraus; Milchabholort bleibt frei; fehlgeschlagener Wachstumssave und erfolgreicher Wiederholungsversuch erzeugen genau einen Bewohner |
| Generiertes Terrain | bestanden; selbst gesammelte Materialien, Werkzeug, Brunnen, frei gewählte Hütte und weitere Transporte nach deren Fertigstellung |
| Separater Prozess auf generiertem Terrain | bestanden; gleicher Wohnraum, Gebäudekollision, Bewohner und Dorfsteuerung |
| OpenGL/Mesa-Darstellung | bestanden; vollständiger Wachstumslauf sowie erneutes Laden und Sichtprüfung bei 1280×720 und 800×900 |

Im Wachstumslauf: vier Unterkünfte mit sechs Schlafplätzen, sechs Bewohner, 64 abgeschlossene Lagertransporte, je 24 Nahrung/Wasser und zwei durch den sechsten Bewohner angelieferte Milch. Die gesamte Prüfung lief auch mit echter OpenGL-Darstellung. Der Terrainlauf errichtete seine Hütte bei `(68.8528, 2.309877, -115.6899)` und lieferte danach drei weitere Einheiten zum Lager. Diese Position ist ein Testnachweis für Seed 15838, kein fest vorgegebener Bauplatz.

Strukturierte Resultate: [results.json](evidence/m6-growth/results.json). Die Nachweise enthalten getrennte Funktions- und Neustartläufe. Die finalen Bilder zeigen den neu geladenen Stand; dabei laufen die gespeicherten Berufe wieder und dürfen Vorräte verbrauchen.

Bildnachweise: [Desktop](evidence/m6-growth/growth-desktop.png), [schmales Fenster](evidence/m6-growth/growth-narrow.png), [eingeklappte Steuerung](evidence/m6-growth/growth-collapsed.png).

Reproduzierbarer Gesamtprüflauf:

```sh
python3 tools/check_village_economy.py --godot /pfad/zu/Godot_v4.6.3-stable_linux.x86_64
```

Der Runner isoliert Spielstände je Test, teilt sie nur für die jeweils zugehörige Neustartprüfung und erkennt auch Skriptfehler bei einem scheinbar erfolgreichen Prozessende. Die neuen Laufzeittests bauen auf der bestehenden flachen Testszene auf; der separate Welttest verwendet die echte `main.tscn` und generiertes Gelände.

## Integrationsumfang

Neue Module: `village_housing.gd` für Zustände, Migration und Wachstum, `village_shelters.gd` für stabile Modelle/Kollisionen. Die bestehende Dorfsteuerung, Navigation, Visualisierung und das HUD werden erweitert. Neue Tests: `tribal_age_growth_contract_test.gd`, `tribal_age_growth_test.gd`, `tribal_age_housing_recovery_test.gd`. Die bisherigen Tests wurden an freie Hüttenplatzierung, den scrollbaren HUD-Bereich und echte alte Feldmengen angepasst.

Es gibt weiterhin einen Arbeitsplatz pro Rohstofftyp und einen gemeinsamen Bauauftrag. Keine Innenraumverwaltung, Bewohner-Todeslogik, Abriss-, Umzugs- oder Rotationsoberfläche, Nachbarstämme oder Mittelalter-Simulation in diesem Paket. D3 muss seine echte Tierproduktion nach dem vorhandenen Liefervertrag anschließen. Die neue Bevölkerung verwendet die vorhandene eigene Kreaturendarstellung; fremde Arten und Zähmung werden nicht angefasst.
