# Entwicklungspfad und Phasenansichten

> Aktueller Ausbau: Der bestätigte Dorfeinstieg ist in [TRIBAL_AGE.md](TRIBAL_AGE.md) beschrieben. Die folgende Dokumentation hält den ursprünglichen PR-23-Planungsstand fest.

Bestätigte Richtung vom 9. September 2026: **Kreatur → Nestgruppe innerhalb der Kreaturenphase → eigentliche Stammesphase mit Werkzeugen, Gruppenaufgaben und Dorfaufbau.**

Dieses Paket auf `agent/species-development-path` erweitert den abgeschlossenen Verhaltensstand aus PR #17 (`15479d8b2b0f5e78e483b806dede879eceda50e3`). Es implementiert die zugehörige Fortschrittsoberfläche und den lesenden Anschluss an gespeicherte Nestgruppen. Es implementiert noch keine Werkzeuge, Baustellen oder steuerbare Stammesphase.

## Bedienung

- **K → Skilltree:** Die Phasenauswahl wechselt die Ansicht. Beide angezeigten Bestände gehören ausschließlich zur gewählten Phase. Die Kampagne bleibt in ihrer tatsächlichen Phase.
- **Kreatur:** Die sechs bestehenden Knoten, vier aktiven Fähigkeiten und sicheren Käufe bleiben erreichbar. Auch nach einem späteren Phasenwechsel können übrige Kreaturenpunkte im Kreaturenbaum ausgegeben werden.
- **Stamm und Folgephasen:** Eigene tatsächliche Bestände, vorgesehene soziale/aggressive Spielhandlungen und gekaufte Vermächtnisse. Keine Kaufbuttons für noch nicht vorhandene Fähigkeiten. Ein Wechsel zur Vorschau darf keine versteckte Kreaturenfähigkeit kaufen.
- **K → Entwicklungspfad:** Drei Schritte erklären, was direkt gesteuert wird und wann Dorfwirtschaft beginnt. Eine gespeicherte Nestgruppe zeigt ihre echte Mitgliederzahl. Ohne Gruppenlaufzeit wird die fehlende Steuerung ausdrücklich angezeigt.
- Vermächtnisse zeigen ausschließlich tatsächlich gekaufte Beiträge. Gemeinsinn/Wehrhaftigkeit sind für die Stammesphase vorbereitet und wirken noch nicht auf Nestbegleiter. Die jeweilige Gruppenmechanik muss ihre Wirkung später tatsächlich anwenden.

## Anschluss an die anderen Chats

Der Entwicklungsstand der anderen Chats ist relevant. Die folgende Prüfung bezieht sich auf die angegebenen veröffentlichten Versionen; neue lokale Arbeiten sind dadurch nicht gemeinsam abgenommen.

| Bereich | Geprüfter veröffentlichter Bezug | Bedeutung für dieses Paket |
|---|---|---|
| Skilltree und Verhalten | PR #17, `15479d8` | Eigene geprüfte Basis; Punkte, Käufe und Begegnungen werden verwendet. |
| Heimat/Nestgruppe | PR #20, `6ca5e48` | Schema-1-Vertrag gelesen. Der CI-Gesamtlauf `34321923374` scheitert bei `home_group_world_test`: kein erreichbarer Heimatplatz auf erzeugtem Startgelände. Kein Laufzeitcode übernommen. |
| Wildtier-KI | PR #21, `ccf4936` auf PR #20 | Eigene Sicht-/Bewegungssteuerung. Keine zweite KI oder Gruppenbefehle in diesem Paket. |
| Menü/Spielstände | PR #16, veröffentlichter Kopf bei Prüfung `374acfd` | Nutzt dieselbe Kampagne. Keine Änderung des Speicherdienstes, keine zusätzliche Speicherversion oder globale Taste. Gemeinsame Pause-/Slotprüfung bleibt Integrationsaufgabe. |
| Artenbuch/Forschung | PR #19, `9a6f637` | Änderungen am gleichen `ui/behavior_skill_tree.gd` später gezielt kombinieren: Buchanschluss aus #19 und Entwicklungspfad/Phasenauswahl aus diesem Paket behalten. Keine Arbeit am Journal selbst. |
| Editor | PR #12, veröffentlichter Kopf bei Prüfung `d566a6c` | Spezies- und Entwurfsidentität weiterverwenden; Körperteile, Ausrichtung und Rendering bleiben dort. |
| Planeten | PR #15, `b870bb6` | Große Planeten/Galaxie bleiben eigener Strang. Der bestehende Nestvertrag ist `legacy_plane_v9`; andere Oberflächen werden hier nicht stillschweigend umgedeutet. |
| Sounds | PR #18, `27043f8` | Audio/Musik bleibt eigener Strang; kein eigener Tonadapter in diesem Paket. |

Es wurden weder diese Fremdbranches noch `main` oder PR #9 zusammengeführt. Der Gruppenvertrag wird mit einem gespeicherten Beispiel geprüft, das unverändert durch `home_group_state.create` aus dem veröffentlichten PR-20-Quelltext erzeugt wurde. Das ist ein Vertragstest, keine behauptete gemeinsame Spielabnahme.

Beim Artenbuch ist die konkrete Überschneidung geprüft: #19 entfernt das eingebettete `_journal` und übergibt über `_open_journal()` die Pause an das gemeinsame Buch. Bei der Integration diesen Buchweg behalten, `_show_development()` und die Phasenauswahl ergänzen und die Kontextzeile an die gemeinsame Seitennavigation anpassen. Der Skilltree-Tab muss dabei wieder die Baumansicht öffnen; nur den Scrollwert zurückzusetzen genügt mit dem neuen Entwicklungspfad nicht mehr. Anschließend K/J, Buchwechsel, Entwicklungspfad, Esc und Speichern/Laden gemeinsam prüfen.

## Daten und Besitz

`ProgressionService.get_development_path()` liest ausschließlich den vorhandenen Körperdatensatz der aktuellen Welt. `core/progression/development_path.gd` prüft die veröffentlichte Struktur `campaign.bodies[integer_seed_as_string].home_group`: Version, Körper-/Spezies-/Gruppenkennung, Oberfläche, zwei eindeutige Mitglieder, Befehle und endliche Ortsdaten.

Der Adapter gibt nur eine neue Zusammenfassung zurück. Er legt keine Körper, Gruppen oder Mitglieder an, schreibt keine eigenen Fortschrittsfelder und löst keine Belohnung aus. Fremde Körper/Spezies, doppelte Kennungen und unlesbare oder neuere Gruppendaten werden nicht als gültige Gruppe dargestellt; der originale Inhalt bleibt unverändert. Neue Gruppenverträge müssen bewusst ergänzt werden.

Eine gültige gespeicherte Gruppe ist **keine** automatische Übergangsfreigabe. Auch Punkte oder ein gekaufter Vermächtnisknoten schalten den Stamm nicht allein frei. Die bestehenden normalen Phasensperren bleiben wirksam.

## Nächste Umsetzung nach der gemeinsamen Nestgruppen-Abnahme

1. Genau einen abgeschlossenen Nestgruppenstand mit Begegnungen, Speichern und Menü prüfen: gleiche Artgenossen nach Laden, keine doppelten Akteure, eindeutiger Besitz von Eingabe/Pause und derselbe Heimatort.
2. Eine kleine vollständige Stammes-Spielschleife bauen: reale Mitglieder einer Sammelgruppe zuweisen, Material am Heimatort einlagern, ein Werkzeug herstellen, eine Behausung errichten, Bewohner versorgen und erweitern. Dabei Bestände, Wege, Arbeitsabschluss und Speicherung tatsächlich verbinden.
3. Erst damit den bewussten Wechsel Kreatur → Stamm freigeben. Spezies, Fraktion, Heimat, Mitglieder, Besitz, Beziehungen, Wallets und Käufe gemeinsam übernehmen. Kein leerer Menüwechsel und keine neue Ersatzgruppe.
4. Stammesfähigkeiten an diese Handlungen anschließen. Erst gemessene Gruppenkoordination/-verteidigung darf als aktiv erscheinen. Soziale, aggressive und gemischte Ausgangslagen testen.

Der Gebäudeeditor soll später eigene Bauformen liefern. Diese Fortschrittsarbeit ersetzt weder den Gebäudeeditor noch das Handwerks-/Bausystem.

## Prüfung

`tests/development_path_test.gd` prüft die echte Spieleroberfläche mit Maus-/Tastatureingaben, alle sechs Phasenbestände, verdiente Punkte und gekaufte Vermächtnisse, unveränderte Speicherbytes beim Betrachten, verbotene versteckte Käufe, den veröffentlichten Nestvertrag, Laden und neue Kampagnen. Die bestehenden Skilltree-/Verhaltensprüfungen bleiben unverändert bestehen.

`tools/review_player_progression.py --development` prüft zusätzlich sechs native Viewport-Aufnahmen bei 1600 × 900 und 800 × 900. Der Exportprüfer führt denselben Test außerhalb des Projekts gegen das tatsächlich exportierte PCK aus; das Testbeispiel liegt nur im separaten Prüfverzeichnis und wird nicht in die Spielkampagne eingeschleust.

Geprüfter Laufzeitstand: `000138882c4a738e697203e54318730c4645e7e9`, Dateibaum `52047958dcd91f62f70eff08fba29e52fec02c97`, [Draft-PR #23](https://github.com/MajorDragonfly/voxelverse/pull/23) auf PR #17. **53/53 [Projektprüfungen](https://github.com/MajorDragonfly/voxelverse/actions/runs/34325321229)** und jeweils **15/15 [Windows-/Linux-Exportprüfungen](https://github.com/MajorDragonfly/voxelverse/actions/runs/34325321214)** bestanden. Die [grafische Abnahme](https://github.com/MajorDragonfly/voxelverse/actions/runs/34325321237) besteht mit sechs neuen und elf bestehenden Aufnahmen. Alle sechs neuen Ansichten und der Kreaturenbaum bei 1280 × 720 wurden visuell kontrolliert; schmale Ansichten scrollen ohne überlagerte Bedienelemente. Vollständige Ergebnisse: `validation/development-path.json`.

Testpakete dieses Skilltree-Zweigs: [Windows](https://github.com/MajorDragonfly/voxelverse/actions/runs/34325321214/artifacts/10093557037) · [Linux](https://github.com/MajorDragonfly/voxelverse/actions/runs/34325321214/artifacts/10093544662). Das enthaltene Spiel-ZIP vollständig entpacken. Neue Entwicklungen anderer Chats sind nicht automatisch Teil dieses Builds. Manueller Spieltest auf dem Ziel-PC bleibt offen.
