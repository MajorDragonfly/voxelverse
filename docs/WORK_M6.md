# Auftrag 5 – dauerhafte Dorfversorgung

Stand: 9. September 2026. Fachbranch `agent/m6-village-economy`, Ausgangscommit `3a3e027` auf dem zusammengeführten `main`. Keine anderen Fachstände übernommen. `ROADMAP.md` bleibt gemäß gemeinsamer Zuständigkeit beim Integrationschat.

Veröffentlichung: Lars hat am 9. September 2026 die Veröffentlichung des fertigen Branches `agent/m6-village-economy` im öffentlichen Repository `MajorDragonfly/voxelverse` bestätigt. Die Übernahme in `main` bleibt Aufgabe der gemeinsamen Integration.

Implementierungscommit: `9d30a0c31bc5da066580a2b58db6be782f899f41`. Dieser Bericht und die Bildnachweise folgen als eigener Dokumentationscommit.

## Gelieferter spielbarer Ablauf

- Brunnen, Forstplatz, Steinbruch und Faserbeet an frei ausgewählten, erreichbaren Bodenstellen bauen. Bestehendes Steinwerkzeug und gemeinsam eingelagerte Materialien werden benötigt; Baukosten werden einmal reserviert und angefangene Baustellen gespeichert.
- Wasser, Holz, Stein und Fasern auch nach erschöpften Startquellen gewinnen. Die Quelle wird produktiv, das Lager wächst erst durch tatsächliche Transporte. Nahrung kommt weiterhin aus dem bestehenden Wurzelgarten.
- Beruf je Bewohner zuweisen; Versorger halten Nahrung und Wasser auf zwölf Einheiten, Holzarbeiter/Steinmetz auf sechzehn, Fasersammler auf zwölf. Baumeister helfen an der laufenden bezahlten Baustelle. Einzelbefehle erhalten die Berufszuständigkeit.
- „Anhalten“ erhält Auftrag, Fracht, Ziel und Arbeitsfortschritt. „Fortsetzen“ nimmt gespeicherte Arbeit wieder auf. Leere Quellen, volle Lager und Essens-/Trinkpausen löschen den Auftrag nicht. Nach einem Hindernis suchen Bewohner selbstständig wieder nach einem Weg.
- D3-Lieferanschluss nimmt fertig produzierte Milch als noch abzuholende Charge an. Milchträger transportieren sie zum gemeinsamen Lager; Bewohner verbrauchen Milch als Nahrung. Nummerierte Quittungen verhindern Doppelannahme beim erneuten Senden nach Save/Load.
- Dorfsteuerung mit getrennten Bereichen für Aufträge und Arbeitsplätze/Berufe, kompakten Bewohnerkarten und einklappbarer Bedienung. Bei der Wahl eines neuen Bauplatzes wird die Welt automatisch freigelegt.

## Integrationsvertrag und gemeinsame Datei

Vollständiger Vertrag: [VILLAGE_ECONOMY_CONTRACT_V1.md](VILLAGE_ECONOMY_CONTRACT_V1.md).

`tribe.schema` steigt von 2 auf 3; das bestehende äußere Kampagnen-/Save-Schema bleibt erhalten. Neue Module und Felder ergänzen dieselbe Dorfstruktur. Migration aus 1/2 erhält IDs, Bewohner, Quellenbestände, Garten, Fracht, laufende Aufträge und Kosten. Kein neuer Bewohner, kein Tier und keine Art werden erzeugt.

Die einzige Änderung in `autoload/save_game_service.gd` ist der Text des vorhandenen Migrationsberichts. Validierung, Migration und Sperre zukünftiger Stammesversionen laufen bereits über den vorhandenen `Tribe`-Anschluss. Dieser kleine Konfliktbereich muss bei der Integration mit anderen Änderungen an der Speicherdatei bewusst aufgelöst werden.

Auftrag 6 kann tatsächliche Dorfereignisse über `community_event` konsumieren; Lieferung/Essen/Trinken führen gespeicherte Sequenznummern. Auftrag 7 behält `order_resolved` und kann vorhandene Status-/Frachtangaben lesen. Diese Änderung vergibt keine Stammespunkte.

## Prüfungen

Godot 4.6.3, keine Skript-/Parserfehler in den erfolgreichen Läufen. Erwartete Warnungen für absichtlich fehlgeschlagene Saves und nicht erlaubte Phasenübergänge werden in den Tests gezielt erzeugt.

| Prüfung | Ergebnis |
|---|---|
| Vollständiger Godot-Import | bestanden |
| Bisheriger Stammestest (`tribal_age_test`) | bestanden; bestätigter Wechsel, dieselben Bewohner, Materialtransport, Werkzeug/Hütten, Save-Rollback und Zukunftsschutz |
| Bisherige erneuerbare Versorgung (`tribal_age_supply_test`) | bestanden; echte Format-1-Migration, Garten, Nahrungslimit, gespeicherte Essenspause |
| Wirtschaftsdatenvertrag (`tribal_age_economy_contract_test`) | bestanden; fremde/ungültige Lieferungen, Sequenzlücken, volle Milchkapazität, beschädigte Unterstrukturen, Doppelbuchungen, begrenzte Produktion |
| Neuer Dorfablauf (`tribal_age_economy_test`, headless) | bestanden; vier frei platzierte Arbeitsplätze, Bau-Save/Load, Berufsaufträge, Fracht-Stopp/Resume, Trinkpause, versperrte Wege, D3-Prüflieferung, fünf erneute Versorgungszyklen |
| Generierter Planet (`tribal_age_world_test -- --economy`) | bestanden; realer Boden, selbst gesammelte Baumaterialien, Werkzeug, Brunnenbau und Wassertransport |
| Separater Neustartprozess (`--restart-check --economy`) | bestanden; identische Bewohner, Brunnenstand, Vorräte und Gruppensteuerung erhalten |
| Reale Darstellung mit OpenGL/Mesa | Wirtschaftslauf und Sichtprüfung in 1280×720 sowie 800×900; einklappbare Steuerung |

Im erfolgreichen headless Wirtschaftslauf: 51 abgeschlossene Transporte, 16 Mahlzeiten, 16 Trinkvorgänge; 36 Wassereinheiten an der Quelle erzeugt, erneuerbares Holz/Stein/Fasern transportiert und 13 Wurzeln nachgewachsen. Nach fünf bewusst erneut ausgelösten Bedarfszyklen waren Nahrung und Wasser wieder auf zwölf Einheiten. Die genaue Anzahl sonstiger Fahrten variiert mit dem Frameablauf; Erhaltungsregeln und Vorratsziele werden geprüft.

Die D3-Prüflieferung umfasst drei Einheiten: erst am Abholort, dann als Fracht gespeichert und neu geladen, anschließend genau einmal eingelagert/verspeist. Beim erneuten Senden derselben Charge bleibt die Gesamtmenge unverändert.

Reproduzierbare gesamte Funktionsprüfung mit getrennten Save-Verzeichnissen und frischem Neustartprozess:

```sh
python3 tools/check_village_economy.py --godot /pfad/zu/Godot_v4.6.3-stable_linux.x86_64
```

Für eine vorhandene Grafiksession kann `tests/tribal_age_economy_test.gd` mit `--rendering-method gl_compatibility -- --capture /absoluter/ausgabepfad` ausgeführt werden. Die neuen Tests und der Runner sind Teil des Branches. Der Format-1-Test wurde an die echte alte Feldmenge angepasst; alte Bewohnerfelder werden unverändert verglichen, neue Felder getrennt geprüft.

Bildnachweise: [Dorfsteuerung bei 1280×720](evidence/m6/economy-desktop.png), [Berufe bei 800×900](evidence/m6/economy-narrow.png), [eingeklappte Steuerung](evidence/m6/economy-collapsed.png). Die strukturierten Ergebnisse liegen in [evidence/m6/results.json](evidence/m6/results.json).

## Geänderte Dateien

- `world/tribe/village_economy.gd` (neu, einschließlich UID): Ressourcen-/Berufs-/Arbeitsplatzvertrag, begrenzte Quellproduktion, Milchlieferbuch und Validierung.
- `world/tribe/tribe_state.gd`: Format 3, Migration und erweiterte Zustandsprüfung.
- `world/tribe/tribe_controller.gd`: Arbeitsplätze, Berufe, Wasser-/Milchtransporte, Trinkpausen, fortsetzbare Befehle und Wegwiederaufnahme.
- `world/tribe/village_navigation.gd`: geprüfte frei gewählte Arbeitsplatzflächen.
- `world/tribe/village_visuals.gd`: neue Quellen, Baustellen, Milchabholung und Frachtfarben.
- `ui/tribe/tribe_panel.gd`: Bedienung und lesbare Zustände.
- `autoload/save_game_service.gd`: Migrationshinweis.
- `tests/tribal_age_supply_test.gd`, `tests/tribal_age_world_test.gd`: Altformatprüfung und optionale generierte Wirtschaftsprüfung.
- `tests/tribal_age_economy_test.gd`, `tests/tribal_age_economy_contract_test.gd` (neu): Laufzeit-/Datenabnahme.
- `tools/check_village_economy.py` (neu): reproduzierbarer Prüflauf.
- Dieser Bericht, der Anschlussvertrag und Bildnachweise.

## Bewusste Grenzen und nächste Integration

D1/D2/D3 wurden weder übernommen noch ersetzt. Echte Milchproduktion am gezähmten Tier bleibt bis zum geprüften D3-Produzenten offen; der Anschluss wird separat mit einer Prüflieferung getestet. Eine Quell-ID allein ist kein Beleg für ein gezähmtes Tier. D3 muss seine fertigen, bereits bezahlten Chargen gemäß Vertrag zuverlässig übergeben.

Brunnen und Rohstoffplätze sind örtliche Produktionsabstraktionen. Kein Anschluss an Grundwassersimulation, bewegte Tiere oder die unfertige Kugeloberfläche. Die Dorfumgebung bleibt auf den vorhandenen sicheren Navigationsbereich und drei ursprüngliche Bewohner begrenzt. Es gibt zunächst einen Arbeitsplatz je Typ und zwei Hütten. Arbeitsplätze sind begehbare Arbeitsflächen; die bisherigen Hütten erhalten in diesem Auftrag keine neue Gebäudekollision. Faserverarbeitung, Wohnraumwachstum, weitere Häuser, neue Bewohner, Nachbarstämme und Tierhaltungskosten sind spätere Pakete.

Der Branch ist zur gemeinsamen Integration vorgesehen. Er führt nichts automatisch nach `main` zusammen und liefert keine gesonderte Windows-Veröffentlichung der parallelen Fachstände.
