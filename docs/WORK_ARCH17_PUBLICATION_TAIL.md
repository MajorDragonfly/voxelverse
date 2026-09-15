# ARCH-17-PUBLISH-TAIL – Cachepflege während der Terrainpublikation

## Umfang und Basis

Teilauftrag vom 15.09.2026, Branch `agent/arch17-publish-tail-20260915`.
Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`, veröffentlichter Kopf
des Integrationskandidaten [PR #110](https://github.com/MajorDragonfly/voxelverse/pull/110).
Der Nutzer hat die Paketauswahl und lokale Umsetzung beauftragt; ARCH-13 und
ARCH-24 werden parallel bearbeitet. Veröffentlichung benötigt gemäß seiner
bisherigen Vorgabe eine ausdrückliche Freigabe. Kein Push, PR oder Merge erfolgt.

## Änderung

Die Cachepflege durchsuchte nach jedem Vorbereitungsschritt den gesamten
vorbereiteten Terraincover. Auf der bestehenden kalten Messroute waren das
2.240 vollständige Durchläufe. Auch Schritte, die nur Wasser, Nodes oder
Kollisionen vorbereiten, bezahlten diese erneute Zählung.

`AdaptiveSphereTiles` führt jetzt die ausschließlich vom Staging gehaltenen
Meshes als Zähler. Ein neuer Meshupload und die Übernahme aus dem Cache erhöhen
ihn; Übergabe, Generationsabbruch und Weltabbau setzen ihn zurück. Bereits
sichtbare, gemeinsam verwendete Blätter werden weiter genau einmal gezählt.
Die normale Cacheprüfung benötigt damit konstanten Aufwand. Bei tatsächlicher
Verdrängung wird die Reihenfolge der ältesten Einträge beibehalten, mit einer
gemeinsamen Schlüsselliste für den jeweiligen Durchlauf.

Die vorhandene Messroute erfasst zusätzlich die Zeiten für Cachepflege,
Jobübernahme, Übergabe, Kollisionswechsel, Teilabbruch und Übergangsende.
Die Instrumentierung liegt ausschließlich in einer Unterklasse des Messwerkzeugs.
Die Spiellaufzeit bekommt lediglich den Zähler und dessen Diagnosewert.

Keine zweite Queue, keine neuen Worker und keine Änderung an Terrainformen,
Materialien, IDs, Speicherformaten oder dem Übergabe-/Kollisionsverfahren.
Grenzen bleiben: zwei Vorbereitungsschritte pro Frame, kooperativ 4 ms,
768 sichtbare Blätter, 24 aktive Bodenkollisionen, 256 Cacheeinträge und
1.536 residente Terrainteile. Diese Zählung ist kein Bytebudget.

## Vergleich

Drei kalte Prozesse vor und drei nach der Änderung, mit identischem Messcode,
Godot 4.6.3, Linux/headless und isolierten Benutzerdaten. AMD EPYC 9V74 auf einer
geteilten Entwicklungsmaschine. Die feste Route verwendet Revision-4-Terrain
an einer Cube-Flächenkante, 32 m Vorlauf, Richtungswechsel, Teilabbruch und Abbau.
Die Tabelle zeigt den Median der jeweiligen drei Prozesswerte, keine
zusammengefasste Frameverteilung.

| Messgröße | Basis | Änderung |
|---|---:|---:|
| Cachepflege insgesamt, 2.240 Aufrufe | 589,603 ms | 5,219 ms |
| Größter Cacheaufruf | 2,432 ms | 0,123 ms |
| 95. Perzentil eines Terrain-Prozessschritts | 1,071 ms | 0,232 ms |
| Größter Terrain-Prozessschritt | 11,736 ms | 10,142 ms |
| Größter Upload-/Vorbereitungsblock | 3,801 ms | 1,336 ms |
| Größte vollständige Übergabe | 5,711 ms | 6,041 ms |
| Schrittweiser Kaltaufbau, Wandzeit | 14,400 s | 13,932 s |
| Abbau mit laufendem Worker | 604,914 ms | 517,974 ms |

Damit entfallen in dieser Route rund **99,1 % des gemessenen Cachepflegeaufwands**.
Die vollständige Übergabe wird durch dieses Paket nicht beschleunigt; ihre
Messwerte und die verbleibenden Spitzen sind ausdrücklich mit ausgewiesen.
Alle sechs Läufe bestanden: jeweils 651 residente Terrainteile in der Spitze,
414 ausstehende Vorbereitungen, 222 Cacheeinträge und abschließend 24 aktive
Kollisionen. Die zusätzliche Queue für Kollisionsnachbarn blieb auf dieser
stationären Richtungswechselroute leer; reale Bewegung prüfen die Fachtests.

Die erste Diagnosemessung hatte einen 30,882-ms-Ausreißer in der Cachepflege.
Sie bleibt als Rohbefund erhalten und geht nicht in den Dreiervergleich ein.
Die sechs Läufe wurden nacheinander ausgeführt (zuerst Basis, dann Änderung),
nicht randomisiert. Aus diesen CPU-Messungen folgt keine Ziel-PC-/FPS-Garantie.

## Fachprüfung

- `terrain_lookahead_test`: echter Kampagnenstart und Spieler, erzwungene
  Flächenkantenplatzierung, A→B→A-Generationen, Pause, fehlender/wiederhergestellter
  Boden, teilweise vorbereiteter inaktiver Collider, Ursprungskorrektur,
  vollständiger Teilabbruch und Weltabbau mit laufendem Worker. **520 zusätzliche
  Bestandsprüfungen** zählen reale Meshbesitzer unabhängig vom neuen Zähler;
  gemeinsamer Cover, Mesh vor Node, Cache, auslaufender Cover und leeres Staging
  sind nachweislich durchlaufen. Cachewiederverwendung ist geprüft.
- `adaptive_planet_test`: 246 m Bewegung, zwei Cube-Flächen, vier
  Ursprungskorrekturen und 756 erfolgreiche physikalische Kantenstrahlen;
  bestehende Geometrie-/Nahtprüfungen bestanden.
- `large_planet_runtime_test`: drei Körpergrößen, jeweils über 167 m Weg und
  zusammen **5.237 erfolgreiche Bodenstrahlen**. Kein Unterschreiten der
  vorhandenen Boden-/Objektgrenzen.
- Quellenverträge, Ressourcenimport und Art-Quellenprüfung bestanden.

Der erste Kampagnentest wurde vom vorhandenen Runner wegen Exit 0 als Erfolg
gemeldet, lieferte aber keine abschließende `TERRAIN_LOOKAHEAD`-Meldung. **Dieser
Versuch gilt hier als unvollständig und nicht als Fachnachweis.** Der Test
protokolliert jetzt seine Stationen und meldet einen regulären vorzeitigen
Abschluss als Fehler. Ein gezielter Nachlauf mit vollständiger positiver
Ergebnismeldung bestand; die Ursache des ersten unvollständigen Protokolls wurde
nicht reproduziert. Originalbericht und Log bleiben unverändert erhalten.
Die Übergabe prüft die tatsächlich vorhandenen Abschlussmeldungen zusätzlich
zum Runnerstatus, siehe [acceptance.json](evidence/arch17-publication-tail/acceptance.json).

Prüfstände, jeweils ohne getrackte Änderungen während der Ausführung:

- Basismessung `84d8f318ad1920a99653e71cee7fe6f072a3ec46`: lediglich Messwerkzeug
  gegenüber der Integrationsbasis ergänzt; Terrain unverändert.
- Optimierung und drei Kandidatenmessungen, adaptive/große Planeten:
  `6dcddc09aa0f6f46363ef377058ed79725a48a9d`.
- Vollständiger Kampagnennachlauf: `2569690ed47547727520bd1bacc59f391d3747a0`,
  Tree `ce7a673342208199a5c65da69750d9b0543de858`. Dieser Folgecommit ergänzt nur
  Fortschrittsmeldungen/Abschlussprüfung des Kampagnentests. Terrain, Messroute
  und die beiden übrigen Tests sind gegenüber `6dcddc0` byteidentisch.

Der konservative Diffplan erweitert wegen des Messwerkzeugs unter `tools/`
auf sämtliche 180 Tests. Gemäß Fachchat-Regel aus `AGENTS.md` wurde stattdessen
der tatsächliche Terrainablauf mit seinen direkten Verbrauchern geprüft.
Weder Testregistry noch Planungsregeln wurden dafür geändert. Der volle
Integrationslauf und native Exporte verbleiben bei der Integration.

## Wiederholung und Integration

Fachlauf mit dem vorhandenen Runner und einem neuen Ausgabeverzeichnis:

```sh
python3 tools/validate_godot.py --godot /path/to/Godot_4.6.3 --skip-main \
  --tests terrain_lookahead_test adaptive_planet_test large_planet_runtime_test \
  --output /tmp/arch17-tail-check
```

Die ausgeführten Nachläufe verwendeten `--skip-import`, weil derselbe lokale
Ressourcenstand zuvor erfolgreich importiert war. Bei einem neuen Checkout
den Import wie oben mitlaufen lassen. Der CPU-Aufruf ist weiterhin
`--headless --path . --script res://tools/benchmark_surface_publication.gd -- --terrain`.
Er wurde über `validation_support.isolated_env()` und `validation_editor()`
mit getrennten Benutzerdaten gestartet; der exakt ausgeführte Python-Runner
liegt als Nachweis bei (seine ursprünglichen lokalen Pfade bei Wiederholung anpassen).

[Alle Rohberichte, Befehle und Quellenhashes](evidence/arch17-publication-tail/README.md)
· [Maschinenlesbarer Vergleich](evidence/arch17-publication-tail/comparison.json).

Zur Integration werden drei Quelldateien und diese paketbezogene Übergabe
übernommen. Zentrale Statusseiten bleiben beim Integrationschat. Die Grenze
dieses Pakets sind die wiederholten Bestandsdurchläufe; die übrige synchrone
Jobübernahme, vollständige Coverübergabe und endgültige Worker-Abwicklung bleiben
mögliche Spitzen. ARCH-17 insgesamt, Windows-/Grafikprüfung und Lars' Ziel-PC-Abnahme
bleiben offen.
