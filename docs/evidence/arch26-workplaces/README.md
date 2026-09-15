# ARCH-26: Prüfnachweise

Basis: `1d6573d9551c3f24bf1dd6fa64e5c301583a26c8`.
Engine: Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless.
Jeder Fachlauf verwendet die isolierten Benutzerdaten des vorhandenen Runners.
Die drei unten dokumentierten Fachläufe liefen jeweils mit sauberem Quellstand.

| Lauf | Quellcommit | Ergebnis |
|---|---|---|
| `qa-final` | `a3d0a1af6b2bcea300a0cf5fdef4561759c4743e` | 21 von 22 Fachtests erfolgreich, Quellenprüfung erfolgreich. Neue Laufzeitprobe meldete einen verfrühten Abholungsbeobachtungspunkt. |
| `qa-followup` | `ffc7e7696e3ce8336298c9705ccba2833bf400f7` | 6 von 7 Fachtests erfolgreich, Quellenprüfung erfolgreich. Die Laufzeitprobe suchte Tierkomponenten vor deren Spawn. |
| `qa-runtime-final` | `5d49a2f1a0bfe2c52498abcd0fef14ebd3604fe4` | Laufzeitprobe und Quellenprüfung erfolgreich. Nur der Zeitpunkt der Komponentenprüfung wurde seit dem vorigen Lauf geändert. |

Damit liegen erfolgreiche Nachweise für **22 unterschiedliche Fachtests** vor,
verteilt auf diese konkreten Quellstände. Das ist kein erneuter Gesamtlauf aller
22 Tests am letzten HEAD und keine Freigabe der gesamten Kampagne.

Der letzte Lauf prüft die reguläre Kugelwelt, zwei physisch gebaute Forstplätze,
Materialanlieferung, Bewohnerzuordnung über die UI, Stop/Fortsetzen, getrennte
Abholorte, Schreibfehler/Rollback, fremde Arbeitsplatz-IDs, zertifizierte Nah-/Fern-
Wege, Live-Save/Load und Ab-/Wiederanmeldung des Tier-Ladesignals. Die zwölf
Layoutfälle bestehen aus DE/EN × drei Fenstergrößen × 100/150 Prozent Schrift.
Sie sind geometrische Headless-Prüfungen, keine gerenderten Bildschirmaufnahmen.

Der Fachvertrag prüft zusätzlich alle acht Arbeitsplätze, voneinander unabhängige
Produktion, volle Lager, gleiche Typen in zwei verschiedenen Siedlungen, falsche
Querverweise und Materialmengen, Berufsbelege und einen echten Godot-Neustart mit
gehaltener Wasserfracht und einer zweiten Forstplatzbaustelle. Zukunftsversionen
blockieren Laden, Backup-Rückfall und Schreiben; erwartete Warnungen in diesen
Fehlerfällen sind im Rohlog erhalten.

## Befehle und Dateien

- [Vollständiger Bericht mit exakten Befehlen, Trees und erfolgreichen Tests](report.json)
- [Erster Fachlauf](qa-final-results.json)
- [Gezielte Nachprüfung der Härtung](qa-followup-results.json)
- [Abschließende Laufzeitprüfung](qa-runtime-final-results.json)
- [Unveränderte Rohlogs einschließlich Diagnoseläufen und Import](raw-logs.zip)

Nach dem erfolgreichen Ressourcenimport liefen die Fachprüfungen mit
`--skip-import --skip-main`. Die späteren Änderungen waren GDScript; Katalog,
PO-Dateien und sonstige importierte Ressourcen blieben unverändert. Import und
Art-/Quellenprüfung des importierten Vorstands stehen unter `qa-final-import`
im Archiv. Dieser frühe Import hat einen als verändert markierten Arbeitsstand
und wird nicht als sauberer abschließender Quellnachweis ausgegeben.

## Korrigierte Diagnosebefunde

- Die frühere Verwendung einer Integer-Liste beim Versionsvergleich erkannte
  JSON-Fließkommazahlen nicht als dieselbe Version. Explizite Zahlenvergleiche
  erhalten die bisherigen Versionen 1 und 2.
- Direkt zugewiesene Brunnenarbeit erhält jetzt denselben Berufsbeleg wie
  Versorgungsarbeit. Der Nachweis trägt die tatsächliche Quell-ID.
- Ein Altstand-Test hatte nur das Dorf per JSON gewandelt und mit der noch
  ungewandelten Körperhülle verglichen. Beide Teile stammen nun aus demselben
  vollständigen JSON-Vertrag; Präzision und Zahlenrepräsentation bleiben konsistent.
- Im realen Ladevorgang reagierten entfernte Tierkomponenten noch auf
  `game_loaded`. Benannte, an Ein-/Austritt gebundene Listener beheben diesen
  tatsächlichen Lebenszyklusfehler; Wiedereintritt und Live-Laden sind geprüft.
- Für den Abholungsnachweis warten Bewohner während der Layoutmatrix und werden
  einzeln fortgesetzt. Die Prüfung der Tierkomponenten erfolgt nach deren Spawn.
- Ein beschädigter erster Arbeitsplatz wird unabhängig von der Reihenfolge der
  gespeicherten Schlüssel abgefangen, bevor der zweite auf ihn zugreift.

Keine Windows-/Export-, native Grafik-, Ziel-PC-/FPS- oder vollständige
Integrationsfreigabe. Die externe Branch-Veröffentlichung wurde von der
automatischen Freigabeprüfung abgelehnt und wartet auf ausdrückliche Zustimmung.
