# Übergabe Auftrag 2 – Passprüfung B2

9. September 2026 · Branch `agent/creature-body-fit`.

## Basis und Umfang

Gemeinsames `main`: `3a3e0272375e556f3ff65b7370582af79a9d48b5`. Vor Beginn und vor Veröffentlichung erneut gefetcht. Dieses Folgepaket baut ausschließlich auf dem eigenen abgeschlossenen B1-Stand `004d5a62b4010b147a1975ccafa604bada7c5295` ([PR #29](https://github.com/MajorDragonfly/voxelverse/pull/29)) auf. B1 ist noch nicht in `main`; der Folge-PR richtet sich deshalb zunächst gegen `agent/creature-body-contract`. Integration in der Reihenfolge B1, dann B2. Keine fremden unfertigen Branches übernommen und kein Merge nach `main`.

## Ergebnis

- Passprüfung von Sattel, festem Probereiter, Geschirrpolstern und Zugleinen gegen echte Körper-/Teilevoxel.
- Rote Problemstellen, anklickbare Anbauteile und geprüfte Freiraumvorschläge mit sichtbarer Lage vor dem Übernehmen.
- Auffällige Ruhelängendehnung je Bein/Teil-UID, gezielte Segmentanpassung mit Prüfung an einer Kopie und weiterhin manueller Gelenkbearbeitung.
- Undo/Redo sowie Speichern und Laden in einem neuen Godot-Prozess. Ein laufender Test wird für die Momentaufnahme angehalten; alte Markierungen verschwinden beim Weiterlaufen.

Verbindlicher Nachweisvertrag: [CREATURE_BODY_FIT_CONTRACT.md](CREATURE_BODY_FIT_CONTRACT.md). Maschinenlesbare Befunde und Messungen: [creature-body-fit.json](../validation/creature-body-fit.json).

## Dateien und Speichervertrag

Neue Laufzeitmodule: `creature_body_fit.gd`, `creature_body_fit_shapes.gd`, `creature_voxel_overlap.gd`. Die eigene `creature_editor_attachment_studio.gd` zeigt und bearbeitet Befunde. `creature_body_attachment_guides.gd` verwendet dieselben Formen wie die Prüfung; `creature_body_contract.gd` ergänzt je Fuß die Ruhelängendehnung. Der Voxelmesher ergänzt ausschließlich kompakte Belegungsmetadaten seiner bestehenden Primitiven. Neue Tests, Screenshot-Einstieg und Workflow heißen jeweils `creature_body_fit` beziehungsweise `creature-body-fit`.

Kein neues gespeichertes Feld und keine Migration. B1-Anschlüsse und vorhandene Gelenkparameter werden weiterverwendet. Keine Änderung an Artenrollen, Zähmung, Wirtschaft, Kampagnenspeicherung, Audio, Roadmap oder fremden Integrationsaufträgen.

## Prüfungen

Godot 4.6.3. Lokal erfolgreich: `creature_body_fit_test`, `creature_body_contract_test`, `creature_joint_studio_test`, `creature_parts_studio_test`, `runtime_geometry_batch_test`. Quellprüfung des Screenshot-Einstiegs ebenfalls erfolgreich.

Der neue Test prüft belegte/leere Voxel, Berührung, kleine Durchdringung, gedrehte Boundingbox-Leerräume, unbekannte Geometrie und Suchbudget, zwei/vier/sechs Beine, unveränderte Befunde bei gedrehtem/ungleich skaliertem Weltbezug, einen lokal gedrehten/skalierten Hornkörper, alle drei Anschlusskorrekturen, ausgeschaltete/zukünftige Anschlussdaten, ausgeschlossene Hilfsgeometrie, veraltete Vorschläge, gezielte Beinänderungen, Undo/Redo und Speichern/Neustart. Die bestehende Gelenkprüfung deckt weiterhin Rampen, Stufen und Fußkontakt ab.

Die lokale Umgebung hat keinen nutzbaren Grafikdisplay. Die ergänzte CI-Abnahme erzeugt echte Werkstattaufnahmen in Compatibility und Forward+ für Befunde, Korrekturen, 1280×720 und einen angehaltenen Rampenlauf. Der bestätigte Lauf wird nach Veröffentlichung hier ergänzt.

## Grenzen

Eine kollisionsfreie feste Passprobe ist kein fertiges Reitsystem und bestätigt weder Sattelauflage noch Tragfähigkeit eines Tiers. Ausrüstung gegen Ausrüstung, ein beliebig großer Bewohner und der komplette überstrichene Raum eines Gangzyklus sind nicht Gegenstand dieses Pakets. Die Werkstatt-Streckgrenze ist ein Bearbeitungshinweis; D1 besitzt die fachliche Eignungsentscheidung. Der in B1 bereits auf unverändertem `main` nachgewiesene intermittierende Audio-Abschlussfehler der Gesamtpaketabnahme bleibt außerhalb dieses Pakets.
