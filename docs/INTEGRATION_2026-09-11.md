# Voxelverse – Kugelintegration vom 11. September 2026

Basis: `bb2f83b56267964baa7037720c4daca26fe3d007`.
Integrationsbranch: `agent/integration-sphere-acceptance-2026-09-11`.
Dieser Bericht dokumentiert den Quellzusammenbau, noch keine bestandene Laufzeit- oder Windows-Abnahme.

## Exakte Übergaben

| Paket | PR | Quellcommit |
|---|---|---|
| ARCH-06 | #78 | `cff4a6928bbac312ea4849e19b9d47bd3fd9d887` |
| ARCH-07 | #81 | `6693a51d941ccd2dd236db07f78ba736ce9d9534` |
| ARCH-22 | #83 | `f2b2ee90838719d8dd2fbb619babeb9e1078e938` |
| ARCH-14 | #79 | `034316fcfe1bd4078671582dcd880209a1c8ad3c` |
| ARCH-24 | #80 | `3930b019b9fb3126cf5b0f285f2178c682c83e30` |
| ARCH-25 | #82 | `15c6f1fbd6c1766aeafcffe490050cea78fb5f07` |

## Gemeinsame Konfliktkorrekturen

ARCH-07 übernimmt den zentralen Save-Teilnehmeranschluss. Der von ARCH-22 ergänzte Zukunftsversionsschutz der Tierhaltung sitzt deshalb im registrierten Tribe-Teilnehmer (`save_participants.gd`), nicht im entfernten Sonderzweig des SaveGameService. Der gemeinsame Writer, Originalschutz und die Double-Präzision aus ARCH-06 bleiben erhalten. Alle Testregistrierungen werden additiv und ohne doppelte Zuordnung vereinigt.

ARCH-14 schützt aktive Tier- und Nahrungszustände über Checkpoint/Regionswechsel. ARCH-24 ergänzt drei Mundmodelle; ARCH-25 ergänzt den DE/EN-Fähigkeitenbereich. Die Eierkette bleibt beim bestehenden D2-Tierbesitzer und der gemeinsamen Dorfwirtschaft. Einzelne Fachprüfungen sind keine gemeinsame Abnahme.

## Prüfgrenzen

Quell-/Importprüfung, echte Kugelvegetation, lange physische Rückreisen, Save-/Neustartketten und native Pakete werden am identischen Integrationsstand geprüft. Bis zum tatsächlich vorliegenden Ergebnis gelten sie hier als offen. Fehlende Vegetation ist bislang eine Nutzerbeobachtung/Testhypothese, kein in dieser Runde reproduzierter Generatorfehler. Es werden keine vorsorglichen Änderungen an Landschaftsseeds oder Tierarten vorgenommen.

Keine Freigabe für 1080p60 auf Zielhardware. Schiffsflug, weitere Epochen, mehrere spielbare eigene Siedlungen und Online-Community bleiben getrennte Arbeitspakete. Hauptbranch und fremde Arbeitsbranches werden vom Integrationsworkflow nicht verändert.
