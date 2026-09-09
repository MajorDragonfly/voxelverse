# Übergabe Auftrag 2 – Sitzpassung B3

9. September 2026 · Branch `agent/creature-seat-fit` · [PR #38](https://github.com/MajorDragonfly/voxelverse/pull/38).

Implementierung **`d48dfcf836bad549cbc357de4d86841a71329b80`**, Quellbaum **`5635e473e1d5480ba60bfba79d6701c7006e16ef`**. Nachfolgende Änderungen dieses Pakets ergänzen ausschließlich Übergabenachweise.

## Basis und Ergebnis

Gemeinsames `main` vor Beginn erneut geprüft: `3a3e0272375e556f3ff65b7370582af79a9d48b5`. Dieses Paket baut auf dem eigenen B2-Abschluss `e2132d6e38bb4c546d6e1a434575caf7ec3b0ee5` aus [PR #35](https://github.com/MajorDragonfly/voxelverse/pull/35) auf. B1/B2 sind noch nicht integriert; der Folge-PR hat deshalb zunächst `agent/creature-body-fit` als Basis. Reihenfolge B1 → B2 → B3. Keine fremden unfertigen Branches übernommen und kein Merge nach `main`.

Sattelauflage und schwebender beziehungsweise einsinkender Reiter werden geometrisch gemessen. Reitergröße, Beinabstand und Sitzhöhe lassen sich speichern. Ein Sitzvorschlag verbindet passende Auflage und Freiraum mit einer ausdrücklich übernehmbaren Änderung. Laufen/Rennen werden auf Ebene, Rampe und Stufen an einer isolierten Kopie geprüft; Treffer lassen sich im Testlauf ansehen. Fußkontakt und zusätzliche Beindehnung werden je Strecke ausgegeben.

Vertrag: [CREATURE_SEAT_FIT_CONTRACT.md](CREATURE_SEAT_FIT_CONTRACT.md). Messwerte: [creature-seat-fit.json](../validation/creature-seat-fit.json).

## Grenzen und Eigentümer

D1 besitzt weiterhin die Eignung. Keine Änderungen an Zähmung, Wirtschaft, Kampagnendaten, globalen Speicherdiensten, Audio, Roadmap oder fremden Fachbranches. Die vorhandenen Stilvorgaben `art/STYLE_GUIDE.md` und `docs/CREATURE_VOXEL_STYLE.md` wurden berücksichtigt; eine neue gemeinsame UI-Designvorgabe war beim Start noch nicht auf `main` vorhanden.

Der neue optionale Block `body_attachments.fit_profile` hat Schema 1; B1-Schema und V7 bleiben bestehen. Altstände erhalten beim Lesen dieselben Maße, ohne dass ein neues Feld gespeichert oder eine Art neu erzeugt wird. Unbekannte Versionen bleiben erhalten. Prüfungen verwenden eine geometrische Referenzfigur, keine fertige Bewohneranimation. Die Bewegung wird in dichten Einzelposen geprüft, der kontinuierlich überstrichene Raum ist ausdrücklich nicht freigegeben. Auflagepunkte ersetzen keine Tragfähigkeits-/Lastsimulation.

## Geänderte Dateien

Neue Module `assembly/core/creature_rider_profile.gd`, `creature_saddle_support.gd`, `creature_fit_motion_review.gd` und `creature_editor_seat_studio.gd`. Die bestehenden eigenen Körper-Passformen, Prüfungen und Hilfsmodelle übernehmen die Maße; die Laufzeitvorschau reicht den gespeicherten Block weiter. `creature_editor_runtime.gd` wählt die neue Werkstatterweiterung als Oberklasse. Weitere Änderungen sind der Sitztest, sein Aufnahme-Einstieg, die neue CI-Abnahme, Dokumentation und Messwerte.

## Prüfung

Godot 4.6.3. Acht relevante Tests lokal erfolgreich: `creature_seat_fit_test`, `creature_body_fit_test`, `creature_body_contract_test`, `creature_joint_studio_test`, `creature_parts_studio_test`, `runtime_geometry_batch_test`, `modular_assembly_framework_test`, `discovery_journal_test`. Die letzten Anpassungen an Prüfgeometrie und Isolation wurden mit Sitz-/Passprüfung erneut geprüft. Der Aufnahme-Einstieg besteht Godots Quellprüfung.

Die Sitzprüfung deckt fehlende/falsche/zukünftige Daten, drei Referenzgrößen, echte Hauttreffer, schwebende/eindringende/seitlich fehlende/zu stark geneigte Auflage, übereinstimmende Darstellung und Kollisionsformen, gezielte Sitzkorrektur, atomisches Undo/Redo und Laden in einem neuen Prozess ab. Alle sechs Bewegungsszenarien werden mit zwei, vier und sechs Beinen geprüft. Eine zusätzliche Probe am Arm des Vierbeiners erzeugt gezielt einen erst später auftretenden Treffer. Die isolierte Prüfung verändert weder Entwurf noch ursprüngliche Testpose; Abbruch und Schließen der Werkstatt geben ihre Ressourcen frei. Die Kopie greift nicht in Physik oder Teileauswahl ein.

| Beine | Geprüfte Posen | Mindestens aufgesetzte Füße | Größte Bodenunterschreitung | Größter Gesamt-Streckfaktor |
|---:|---:|---:|---:|---:|
| 2 | 958 | 1 | 0,000000182 | 1,215 |
| 4 | 944 | 2 | 0,000000195 | 1,295 |
| 6 | 616 | 3 | 0,000000343 | 1,937 |

Insgesamt **2.518 Posen**. Die angepassten Zwei-/Sechsbeiner haben in diesen Posen keine Reiter-/Geschirrtreffer. Beim Vierbeiner erzeugt die gezielte Armprobe 33 Trefferposen; der erste Treffer liegt nach Bewegungsbeginn. Die absichtlich ungünstige Sechsbeinmischung zeigt trotz Fußkontakt erhebliche zusätzliche Dehnung. Dieses Paket verschweigt diesen Befund nicht und erklärt das Tier nicht eigenständig für geeignet. Die korrigierte Sattelauflage erreicht bei den Referenzformen 9/9 Punkte mit Lücken von 0,025 bis rund 0,060 Entwurfseinheiten vor Körpermaßstab; Beckenabstand zum Sattel 0,01.

**B2-Nachtrag:** Die zuvor wartende [Grafik-/Fachabnahme 34347964334](https://github.com/MajorDragonfly/voxelverse/actions/runs/34347964334) ist inzwischen erfolgreich. Sie prüft B2-Implementierung `beda03adf70de89af206a46495a87c1c173de34f`: Import/Quellprüfung, fünf Fachtests sowie echte Werkstattaufnahmen in Compatibility (OpenGL) und Forward+ (Vulkan), einschließlich 1280×720. Das ist ein Nachweis für B2, nicht automatisch für dieses Folgepaket.

Die eigene [B3-Grafikabnahme 34351147965](https://github.com/MajorDragonfly/voxelverse/actions/runs/34351147965) prüft exakt den oben genannten Implementierungscommit. Sie erzeugt Aufnahmen für einen schwebenden Sitz, die korrigierte Auflage, das Bewegungsprotokoll und ein kleines Fenster in Compatibility und Forward+. Zum Übergabestand wartet der Lauf auf einen GitHub-Runner (`queued`). Lokales Grafikdisplay ist nicht verfügbar; eine erfolgreiche B3-Grafikabnahme oder manuelle Bildsichtkontrolle wird deshalb noch nicht behauptet.
