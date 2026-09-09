# D1.1 – geprüfte Tierkörper und wiederaufnehmbare Habitatsuche

9. September 2026 · Branch `agent/d11-fauna-body-evidence`.

## Prüfreferenz und Abhängigkeiten

- Gemeinsame Basis: `3a3e0272375e556f3ff65b7370582af79a9d48b5`.
- Abgeschlossenes D1 aus PR #33: `17b23f568dabbec9f3903217238650f0c9178d04`.
- Abgeschlossener B1-Körpervertrag aus PR #29: `004d5a62b4010b147a1975ccafa604bada7c5295`.
- Versionierter D1.1-Vertrag: `ce8011ec0a5896acd66ca0ec92397886560eafa2`.
- Implementierung: `6f118992f87f176f13ce3efd8670d3b93c58b6c7`.
- Geprüfter Quellbaum: `68474d19b51c5cd52dd4a731c15603170602c54b`.
- Lokaler Prüfcommit: `bd1b32f36b729d4a35770c2e11fcf767ca192e78`;
  lokaler Vertragscommit: `dfdaf13495d3584556d4db8f170c92cbb71894b8`.
  Die veröffentlichten Git-Dateibäume entsprechen exakt den lokalen Bäumen;
  nur die Commit-Metadaten des GitHub-Anschlusses unterscheiden sich.

Der nachfolgende Commit ergänzt ausschließlich diesen Übergabebericht.
Die beiden abgeschlossenen Abhängigkeiten bleiben in der Historie erhalten.
Unfertige Körperpassung, D2, UI und Planeten-Erweiterungen wurden nicht
übernommen. Kein Merge nach main, keine Änderung an ROADMAP.md.

## Ergebnis

D1-Pflichtarten erhalten einen separat versionierten anatomischen Nachweis,
der an den eingefrorenen Bauplan gebunden ist. Die echte B1-Laufzeit bestätigt
Beinrigs, Fußkontakte, Beindehnung und Stützfläche. Das Zug-/Reittier benötigt
zusätzlich die tatsächlichen Sattel- und beiden Geschirranschlüsse außerhalb
der Voxelhaut. Ungeeignete Körper gelangen nicht in den aktiven Tierbestand.

Vorhandene D1-Körper ohne B1-Anschlussblock werden mit den lesenden
B1-Altstandparametern geprüft. Sie erhalten ausschließlich den separaten
Nachweis. Bauplan, Art-ID, Name, Begegnungen und Beziehungen bleiben bestehen.
Gespeicherte Nachweise werden nach einem Neustart wiederverwendet. Ein
abgelehnter Körper wird nicht bei jedem Spawnversuch neu aufgebaut.

Ein früheres `unavailable` beendet die Habitatsuche nicht mehr dauerhaft:
Eine gespeicherte Rastersuche prüft kurze, miteinander verbundene Geländewege.
Sie kann Wege um Terrainbarrieren finden, die direkte Radiallinien verfehlen.
Ein bereits erreichbares Vorkommen dient als Ausgangspunkt; sein bisheriger
Zugangsweg bleibt erhalten. Die Suche ergänzt fehlende Rollen und bewahrt
vorhandene Habitatkennungen, Objektgenerationen und Ersatzzeitpunkte.

Der nächste Suchknoten und seine nächste Richtung liegen im Kampagnenzustand.
Ein Prozessneustart setzt mitten im Knoten fort und erzeugt dieselben neuen
Wege und Kennungen wie der ununterbrochene Lauf. Nach abgeschlossenem Aufbau
funktionieren tatsächlicher Spawn, Futterquellen, Gesamtlimit und Save/Load.

## Vertrag und Einbaupunkte

[D11_DATA_CONTRACT.md](D11_DATA_CONTRACT.md) definiert Felder, Prüfregeln und Grenzen.
Katalogschema 1, Generator `domestic_fauna_v1`, Save-Schema 6 und Kampagnenschema 1
bleiben erhalten. Neu sind ausschließlich optionale `species[].body_evidence`
und `fauna_catalog.habitat_recovery`, jeweils mit eigener Version 1.

| Datei / Bereich | Änderung |
|---|---|
| `world/fauna/domestication/domestic_body_evidence.gd` | B1-Messung, D1-Anatomieregeln, Bauplanbindung, gespeicherte Freigabe/Ablehnung |
| `world/fauna/domestication/domestic_habitat_recovery.gd` | Begrenzte, gespeicherte Wegsuche mit erhaltenen Vorkommen |
| `world/fauna/domestication/planet_fauna_catalog.gd` | Optionale Erweiterungen validieren; Zukunftsversionen erkennen |
| `world/fauna/domestication/domestic_fauna_runtime.gd` | Wiederaufnahme und Freigabe des tatsächlich aufgebauten Tiers vor seinem ersten Simulationstick |
| `creatures/runtime/creature_body_contract.gd` | Einziger B1-Codeanschluss: optionales vorhandenes Mesh für `describe`, entsprechend dem bestehenden `resolve`-Parameter |
| Tests und Neustartwerkzeug | Mehr-Seed-Messung, echte Fehlerkörper, Umweg/Blockade, reale Szenen und Prozessneustart |
| `.github/workflows/domestic-fauna-d11.yml` | Wiederholbare Prüfung einschließlich alter und neuer Neustartstrecke |

Für den Kreaturenchat: Die optionale Signatur lautet
`describe(blueprint: Dictionary, skin: ArrayMesh = null)`; Rückgabe und bisherige
Aufrufe bleiben unverändert. Damit benutzt D1 die bereits gerenderte Haut und
das vorhandene Beinrig. Diese kleine Signaturergänzung beim Übernehmen weiterer
Körperpassungsarbeiten erhalten. Keine eigene Ausrüstungspassung implementiert.

Für D2: Der bestehende `object_is_reserved`-Anschluss bleibt erhalten.
Zähmzustand, Besitzer, Stammesfreigabe und deren UI bleiben bei D2. Für D4 ist
ein bestandener D1-Nachweis eine anatomische Voraussetzung; er ersetzt weder
Reiter-/Ausrüstungskollision noch Auf-/Abstieg oder tatsächliche Lastsimulation.

## Abnahme

Godot **4.6.3.stable.official.7d41c59c4**, Headless-Linux, isolierte Spielstände.
**15 Prüfungen bestanden:** Import/Artquellen, D1-Vertrag und Katalog,
Körpernachweise, Habitat-Wiederaufnahme, beide echten Fauna-Szenen, B1-Vertrag,
Entdeckungsbuch, Spielstandplätze und vier Schreib-/Leseprozesse.

| Nachweis | Ergebnis |
|---|---|
| Anatomie | 78 Seeds, 234 Tiere; immer vier reale Beinrigs und bestandene Rollenanforderungen |
| Größter Ruhekontaktfehler | 0,000000164 Entwurfseinheiten bei erlaubten 0,002 |
| Größte gemessene Ruhelängendehnung | 1,00; Arbeitstiergrenze 1,20 |
| Fehlerkörper | Deaktivierter/versenkter Sattel, übermäßige Beindehnung und zu kurze Stützfläche abgelehnt |
| Originale D1-Verteilung | 78 Seeds, 932 Vorkommen weiterhin bestanden |
| Gebogener Inselkanal | Radialsuche scheitert; Wegsuche liefert drei Populationen mit 116–124 Wegschritten |
| Reale Wiederherstellung | Seeds 15838, 63352, 23757 und 1060; beim Inselstart 63352 Fortsetzung vom bereits erreichbaren Einzelvorkommen |
| Echte Spielszene | Drei Rollen und Futterquellen bei Gesamtlimit 3, auch nach Habitat-Wiederherstellung |
| Individuen | Bestehende Habitatgeneration 7 samt Objekt-ID erhalten; Todes-/Ersatzprüfung weiter bestanden |
| Neustart | Besuchsreihenfolge, alte D1-Körper, gespeicherte Nachweise und mitten im Knoten unterbrochene Suche erhalten |
| Versionsschutz | Sieben neue Zukunftsvarianten trotz gültigem älteren Backup weder geladen noch überschrieben; ursprüngliche D1-Schutzfälle weiter bestanden |
| Zusätzliche Live-Körperprüfung | 1,622–1,665 ms einmalig je erstmals geprüfter Art im gemessenen Lauf |

Die Laufzeitmessung enthält die zusätzliche Prüfung am bereits aufgebauten
Tier. Sie ist keine Messung des gesamten Tieraufbaus oder der Ziel-PC-Framerate.
Die erste Umsetzung baute einen zweiten Prüfkörper; das wurde nach gemessenen
Ladespitzen entfernt. B1 kann jetzt das bereits vorhandene Hautmesh verwenden.
Für reine Datentests wird weiterhin ein eigener realer Prüfkörper aufgebaut.

Nachweise: [summary.json](../validation/d11/summary.json),
[body-measurements.json](../validation/d11/body-measurements.json),
[habitat-recovery.json](../validation/d11/habitat-recovery.json),
[runtime.json](../validation/d11/runtime.json),
[source-sha256.json](../validation/d11/source-sha256.json).
Die Neustartprotokolle enthalten erwartete Warnungen der absichtlich erzeugten
Zukunftsstände. Der zuvor an HTTP 500 beim Engine-Download gescheiterte
ursprüngliche D1-CI-Lauf ist nach Wiederholung ebenfalls erfolgreich:
[Domestic fauna D1](https://github.com/MajorDragonfly/voxelverse/actions/runs/34346518370).
Für D1.1 liegt die lokale Abnahme vor; der neue CI-Workflow ist separat zu prüfen.

```sh
python tools/validate_godot.py --godot /pfad/zu/godot --tests domestication_contract_test domestic_body_evidence_test domestic_fauna_catalog_test domestic_habitat_recovery_test domestic_fauna_runtime_test domestic_habitat_runtime_test creature_body_contract_test --skip-main --output /tmp/d11-checks
python tools/validate_domestic_fauna.py --godot /pfad/zu/godot --output /tmp/d1-restart
python tools/validate_domestic_fauna.py --godot /pfad/zu/godot --probe d11 --output /tmp/d11-restart
```

## Verbleibende Grenzen

Die neue Suche ist begrenzt: 4-m-Raster, maximal 16.384 besuchte Punkte,
1.024 m vom Suchursprung, 4.095 Wegschritte und insgesamt 192 Wasserschritte.
Sie wird zwischen Kanten bei ungefähr 2 ms pausiert; eine einzelne vollständige
Kanten-/Routenprüfung kann das Budget überschreiten. Unzugängliches Terrain
oder schmalere Übergänge können weiterhin `blocked` ergeben. Der versiegelte
Testort bleibt korrekt blockiert; die Prüfung behauptet dort keine Population.
Eine mathematische Garantie für sämtliche möglichen Terrain-Seeds folgt daraus
nicht. Geladene Baum-/Felskollisionen prüft weiterhin der vorhandene Spawner.

Die produktive Kugelkampagne bleibt beim Oberflächenpaket. Langfristige
Wasserversorgung, Milch, Reiten und Pflügen werden nicht vorweggenommen.
Grafische und native Windows-Abnahme auf Lars' Gerät bleiben offen.
