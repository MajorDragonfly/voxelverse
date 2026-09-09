# Übergabe Auftrag 2 – Körperanschlüsse B1

9. September 2026 · Branch `agent/creature-body-contract` · [PR #29](https://github.com/MajorDragonfly/voxelverse/pull/29).

**Fachstatus: abgeschlossen und zur Integration überprüfbar.** Der unten dokumentierte allgemeine Audio-Abschlussfehler bleibt eine getrennte Integrationsaufgabe.

## Stand und Umfang

- Ausgangsbasis: zusammengeführtes `main`, **`3a3e0272375e556f3ff65b7370582af79a9d48b5`**; vor Beginn per Git-Fetch und GitHub geprüft.
- Implementierung: **`dba2660586171cd4c2d1e8c0af5acf9f64b2f135`**, Quellbaum **`42b2441ba835d3a50aab9c69a0a2374823217862`**. Danach enthält dieser Branch ausschließlich zusätzliche Übergabenachweise, sofern unten keine Korrektur ausgewiesen ist.
- Keine fremden Arbeitsstände übernommen, kein Merge nach `main`. `ROADMAP.md` und `docs/NEXT_PARALLEL_WORK.md` bleiben beim Integrationschat. Keine Änderungen an Tierrollen, Zähmung, Wirtschaft, Phasen, Spieler-/Wildtierbasis oder globalen Speicherdiensten.

Die vorhandene Werkstatt wurde zuerst auf der gemeinsamen Basis geprüft. Die bestehenden Gelenk- und Teiletests bestanden bereits. Deshalb wurden Beinbewegung und Nivellierung erhalten; dieses Paket ergänzt eine eigene, darauf aufbauende Körper-/Anschlussprüfung.

## Ergebnis

Drei feste gespeicherte Anschlüsse: `saddle.primary`, `harness.left`, `harness.right`. Die Position wird aus dem tatsächlichen Voxelmesh bestimmt und folgt bei Umbau der Wirbelsäule. Die Werkstatt bietet Lage, Versatz, Drehung, Deaktivierung und gespiegeltes Geschirr mit bestehendem Undo/Redo und Speichern. Eine einschaltbare Passprobe zeigt Sattel, Probereiter und Zugleinen auch im Bewegungstest.

Die Laufzeit stellt Anschlüsse relativ zum Körper und als vollständige Welttransformation bereit. Ein externer Ausrüstungswurzelknoten folgt über die feste Kennung, bleibt bei Vorschau-Neubau verbunden und blendet sich bei fehlendem Anschluss aus. Geneigte und nicht einheitlich skalierte Bezugssysteme sowie eine zusätzliche Bewegung von `BodyV4` sind geprüft.

Der Artenkatalog bekommt Geometrienachweise, tatsächliche Beinrig-/Fußdaten und die bei ungleichen Beinen nötige Ruhelängendehnung. **Die fachliche Eignung bleibt vollständig bei D1.**

## Vertrag und Integration

Verbindliche Beschreibung: [CREATURE_BODY_CONTRACT.md](CREATURE_BODY_CONTRACT.md).
Maschinenlesbares Beispiel aus der echten Artenfabrik: [creature-body-contract-example.json](../validation/creature-body-contract-example.json).
Messwerte/Prüfergebnisse: [creature-body-contract.json](../validation/creature-body-contract.json).

| Pfad | Anschluss / Verantwortung |
|---|---|
| `assembly/core/creature_body_attachments.gd` | JSON-Schema 1, feste IDs, deterministische Standards, Datenprüfung und gezieltes Bearbeiten. |
| `creatures/runtime/creature_body_contract.gd` | Körperlokale Posen, Voxeloberflächenprüfung, D1-Deskriptor und messbarer Ruhekontakt. |
| `creatures/runtime/creature_runtime_preview.gd` | Drei Marker an `BodyV4`, `body_socket(id)` und stabile Teil-UID in den Fußnachweisen. |
| `creatures/runtime/creature_body_attachment.gd` | Optionaler externer Ausrüstungswurzelknoten. |
| `creatures/runtime/creature_body_attachment_guides.gd` | Optionale Passprobe, von Anatomiegrenzen/Kollision ausgeschlossen. |
| `creatures/editor/creature_editor_attachment_studio.gd` | Eigene Werkstatterweiterung oberhalb der vorhandenen Gelenkwerkstatt. |
| `creatures/editor/creature_editor_runtime.gd` | Einzige Änderung: neue Erweiterung als Oberklasse. |
| `creatures/editor/creature_assembly_blueprint_v7.gd` | Gezielter Aufruf der Zusatzdatenmigration. |
| `assembly/adapters/creature_assembly_adapter.gd` | Anschlussdaten als Metadaten des vorhandenen Einwegadapters. |
| `tests/creature_body_contract_test.gd` | Neue Daten-/Laufzeit-/UI-Prüfung einschließlich zweitem Godot-Prozess. |
| `tools/capture_creature_body_contract.gd` | Reproduzierbare Aufnahmen der echten Werkstatt. |
| `.github/workflows/creature-body-contract.yml` | Abnahme und beide Renderer. |

Zusätzlich ändern sich nur diese Dokumentation und die beiden genannten Validierungs-JSONs. Es gibt keine neue Arten-/Tierdatenbank. D1 soll die Daten bei Erzeugung oder bewusster Körperänderung auswerten; ein Aufruf der vollständigen Geometrieprüfung für jedes Tier pro Frame ist nicht vorgesehen.

## Speicherung und Migration

Neues verschachteltes Feld `blueprint.assembly.body_attachments`, eigenes Schema 1. Das äußere V7-Format, Spezies-/Design-IDs und Kampagnenspeicherung bleiben bestehen. Nur ein bisher fehlendes Gesamtfeld erhält Standardwerte. Vorhandene ungültige/unvollständige/zukünftige Blöcke werden erhalten und zur Nutzung abgelehnt. Eine deaktivierte Kennung bleibt deaktiviert. Die lesende Auswertung von Altständen verändert nichts.

V7 Save/Load, JSON-Rundlauf des bestehenden Journals, modularer Adapter, Undo/Redo und ein kompletter neuer Godot-Prozess sind geprüft. Es werden keine gestellten Beine oder globalen Reiterpositionen in den Entwurf zurückgeschrieben.

## Prüfungen

Godot **4.6.3.stable.official.7d41c59c4**, isolierte Test-Spielstände. Import und Quellprüfung sowie neun relevante Tests erfolgreich:

`creature_body_contract_test`, `creature_joint_studio_test`, `creature_parts_studio_test`, `creature_studio_test`, `creature_builder_v7_test`, `creature_editor_v7_runtime_test`, `runtime_geometry_batch_test`, `modular_assembly_framework_test`, `discovery_journal_test`.

Nach der letzten kleinen Anpassung an Datenprüfung und Laufzeit-Prozessreihenfolge wurde der neue Körpervertrag erneut erfolgreich geprüft. Der Screenshot-Einstieg wurde zusätzlich mit Godots `--check-only` geprüft. Keine Skript-/Parser-/Laufzeitfehler in diesen erfolgreichen Prüfungen.

Messungen im absichtlich gedrehten, verschobenen und ungleich skalierten Bezugssystem, Toleranz 0,002 Entwurfseinheiten:

| Beine | Maximale Ruheabweichung | Maximales Unterschreiten der Bodenebene bei Bewegung | Mindestens aufgesetzte Füße | Maximales Reiter-Abdriften | Größte Ruhelängendehnung |
|---:|---:|---:|---:|---:|---:|
| 2 | 0,000035 | 0,000271 | 1 | 0 | 1,00 |
| 4 | 0,000097 | 0,000270 | 2 | 0 | 1,00 |
| 6 | 0,000235 | 0,000316 | 3 | 0 | 1,49 |

Die kleinen Kontaktabweichungen enthalten die Float-Rundung bei weit verschobenen Koordinaten. Die bestehende Gelenkprüfung prüft ergänzend physische Rampen-/Stufencollider, Laufen/Rennen und erhaltene Entwürfe. Der radiale Bezugssystemtest ist eine begrenzte Körperprüfung, keine fertig integrierte Kugelkampagne.

**Automatische Grafikabnahme erfolgreich:** [Creature body contract, Lauf 34345073333](https://github.com/MajorDragonfly/voxelverse/actions/runs/34345073333) prüft exakt den oben genannten Implementierungscommit. Daten-/Beintests sowie die echte Werkstatt in Compatibility (OpenGL 4.5) und Forward+ (Vulkan 1.4) bestanden. Je drei Bilder: `body_fittings`, `fittings_slope`, `six_leg_fittings`. Artefakt `creature-body-contract-pull_request`, ID 10101366184, SHA-256 `a6f325dcc4f8aaf7c7df309f895f339d5340e23f394a1ff06eb166aedc4fe119`. Die lokale Grafik konnte nicht starten; der Abruf der CI-PNGs wurde mit HTTP 403 abgewiesen. Eine manuelle Bildsichtkontrolle wird deshalb nicht behauptet.

Auch die separate bestehende Werkstattabnahme, der modulare Bauplantest und die Planetendiversität sind auf diesem Commit in CI erfolgreich. **Die komplette Desktop-Paketabnahme ist noch nicht grün:** [Desktop-Exportlauf 34345073322](https://github.com/MajorDragonfly/voxelverse/actions/runs/34345073322) exportiert erfolgreich und besteht Hauptspiel-/Planetenlaborstart. `packaged_menu_input` erreicht `MENU_INPUT_PASSED`, meldet beim Beenden aber eine verbleibende `OggPacketSequence` aus `res://audio/assets/music/menu.ogg` (Linux und Windows). Der gezielte Vergleich mit unverändertem Basiscommit `3a3e027` reproduziert **dieselbe** Restressource: erster isolierter Basislauf ohne Fehler, zweiter mit Audioleak; der Fachbranch zeigt denselben Fehler. Reproduktion: `godot --headless --verbose --path . -- --input-smoke` mit frischem `XDG_DATA_HOME`. Damit ist der intermittierende Audio-Abschlussfehler als bereits auf der gemeinsamen Basis vorhanden nachgewiesen. Gemeinsame Audio-/Shutdown-Dateien wurden gemäß Arbeitsteilung nicht verändert. Dieser Punkt geht an Chat 7/Integration; B1 ist kein vollständig abgenommenes neues Windows-Gesamtpaket.

## Grenzen und nächster Anschluss

- Es gibt noch kein steuerbares Reiten, Auf-/Absteigen, Geschirrdynamik, Pflügen, Tierbesitz oder Speichern eines Reiter-Tier-Verhältnisses. Diese Spielsysteme gehören zu späterem D4 bzw. D2.
- Der Probereiter hat eine feste Prüfgröße. Seine Existenz bestätigt keine Freigängigkeit eines beliebigen Bewohners. D4 braucht vollständige Ausrüstungs-/Reiterkollision und passende Sitzanimation.
- Der Datenvertrag erkennt einen Anschluss innerhalb der Haut. Er prüft noch keine Überschneidung der gesamten Ausrüstung mit Hörnern, Rückenplatten oder Gliedmaßen.
- Die vorhandene Bodenanpassung streckt extreme Beinmischungen. Der Vertrag legt den Faktor offen; D1 sollte für tatsächlich erzeugte Reit-/Zugtiere eine eigene Grenze verlangen. Freie Gelenkketten, Wasser-/Flugbewegung und anatomische Belastbarkeit sind hiermit nicht abgeschlossen.
- Für D1: `Contract.describe` + `inspect_rest` lesen, erforderliche Kennungen/Fehler und selbst festgelegte Körpergrenzen prüfen. Für D4: Besitzer sucht die tatsächliche Vorschauinstanz, bindet seine Ausrüstung an eine Kennung und bleibt alleiniger Simulationsbesitzer.

Manueller Einstieg: **F2 → Körper → Sattel & Geschirr prüfen**, Anschluss verstellen/spiegeln, speichern, neu öffnen; anschließend **Testlauf** mit Laufen/Rennen und Rampe/Stufen. Lars' Windows-Spieltest bleibt ein eigener Abnahmeschritt.
