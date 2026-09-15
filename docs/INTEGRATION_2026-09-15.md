# Gemeinsame Voxelverse-Integration vom 15. September 2026

Auftrag: sämtliche veröffentlichten Umsetzungen vereinigen und den nächsten Windows-Spieltest bereitstellen. Branch: `agent/playtest-integration-2026-09-15`. Ausgangspunkt ist PR #84 bei `00c04d0ddbf3f11bfc3d794f66b618dbd5814b59`; dieser enthält bereits #78–83 und die nachfolgenden Speicher-/Kollisionskorrekturen. Dazu kommen #85–89 mit erhaltener Quellhistorie. [Exakte Quellcommits](integration-sources-2026-09-15.json).

| Quelle | Integrierter Umfang |
|---|---|
| #78 / ARCH-06 | Präzise JSON- und Regionskoordinaten, Fachinventar |
| #79 / ARCH-14 | Tierzustände über Speichern und Cachefreigabe erhalten |
| #80 / ARCH-24 | Hunde-/Krokodilschnauze und Oktopusmund |
| #81 / ARCH-07 | Feste Speicherteilnehmer, Versionsschutz |
| #82 / ARCH-25 | Fähigkeitenbereich auf DE/EN und kleine Auflösungen |
| #83 / ARCH-22 | Vollständige Eierproduktions-/Transportkette |
| #84 | Gemeinsamer Anschluss; eingefrorene Tierkörper und radiale Stufenkollision |
| #85 / ARCH-27 | Vorbereitende regionale Wege-/Transportmodelle |
| #86 / ARCH-26 | Vorbereitende Siedlungsinstanzen und Kopiermigration |
| #87 / ARCH-17 | Bewegungsabhängige Terrain-Vorausschau, sichere Jobgenerationen |
| #88 / ARCH-14 | Begrenzte Journal-Seiten und gezielte Detailansichten |
| #89 / ARCH-13 | Vollständige Sicherung einschließlich Labor-/Benutzerdateien |

Alle nach dem 10. September veröffentlichten Fachbranch-Spitzen sind enthalten. Der einzige verbleibende gleichzeitige Branch `feature/arch-13-region-archives` gibt eine doppelte Reservierung frei und liefert keinen zusätzlichen Spielcode. Ungespeicherte Fremdarbeit wurde nicht übernommen.

## Gemeinsame Korrekturen

- Prüfkatalog und Planung additiv vereinigt: 165 Godot-Tests genau einmal in 17 Verträgen, 566 Nachrichten je Sprache. ARCH-26-Validatoren ergänzen die bereits integrierte Eierwirtschaft.
- Der tatsächliche Neustart von ARCH-26 reproduzierte stehenbleibende Baufracht: alte verkürzte JSON-Weghashes passten nach präzisem Speichern nicht mehr zum identischen Endpunkt. Neue Schlüssel normalisieren Zahlentypen mit voller Präzision. Alte Schlüssel werden über den exakt gleichen gespeicherten Endpunkt aufgelöst; höchstens 128 bereits zertifizierte Wege werden betrachtet. Fehlende oder nur benachbarte Endpunkte erzeugen keinen Weg. Historische und präzise Dateien, unterbrochene Fracht und getrennte Siedlungen werden im selben Neustarttest geprüft.
- Die D2-Neustartprobe verglich ein separat präzise geschriebenes Körperwörterbuch mit der bewusst erhaltenen Schema-1-Körperdarstellung. Ihr Erwartungswert ist jetzt der rekonstruierte Körper des vor dem Neustart festgeschriebenen Saves, als unveränderlicher Text. Die ursprüngliche Übernahmeprüfung, Körper-/Eigentümeridentität und alle Fehlerfälle bleiben bestehen.
- Die breite Prüfung reproduzierte im bestehenden `planet_streaming_test` einen zweiten Fehler: Ein erzwungener Erstaufbau hinterließ die Startposition als dauerhaften Bewegungshinweis. Nachfolgende Ortsanfragen ohne neuen Hinweis bauten daher erneut den Startbereich. Erzwungenes Laden löscht jetzt den Hinweis; die aktuelle Ortsanfrage bestimmt danach wieder den Fokus. Der unveränderte Übergangs-/Cachetest und die neue Terrain-Vorausschauprüfung bestehen mit dieser Korrektur.

## Prüfung und Veröffentlichung

Import, Artquellen und Vertragsgate bestanden lokal. Die gezielten neuen Modellprüfungen, Terrain-Vorausschau, Journal, eingefrorene Körper sowie die korrigierten Siedlungs-, Fernsimulations-, Eiervertrags- und D2-Neustartprüfungen werden mit isolierten Nutzerdaten ausgeführt. Vollständige Quellprüfung, native Windows-/Linux-Pakete und Grafikworkflows laufen auf dem veröffentlichten Kandidaten. Geplante Prüfungen sind nicht als bestanden zu verstehen; Abschlussnachweise werden separat mit exaktem Commit und CI-Läufen festgehalten.

Der Vorgänger #84 hat auf `00c04d0` bereits erfolgreiche vollständige Quellen- und Desktopexportprüfungen; diese ersetzen die Prüfung der fünf neu integrierten Pakete nicht.

## Grenzen

Siedlungsgründung, produktive Transporte zwischen mehreren Siedlungen, spätere Epochen, Schiffsflug und Online-Community sind weiterhin eigene Aufträge. Globale Langzeitregister, Bereinigung und 1080p60 auf dem Ziel-PC sind nicht durch den Spieltest abgeschlossen. Kugelwelt bleibt der einzige reguläre Spielweg. [Aktuelle Folgearbeiten](NEXT_PARALLEL_WORK.md), [manueller Spieltest](WINDOWS_TEST_2026-09-15.md).
