# Spielerfortschritt: spielbare Begegnungen

Auftrag vom 9. September 2026: reale Sozial-/Aggressionspunkte und wirksame Fähigkeiten auf dem geprüften Skilltree aus PR #14 umsetzen; die folgenden Spielphasen mitplanen. Das Entdeckungsbuch gehört jetzt einem anderen Chat. Dieser Arbeitszweig ist `agent/creature-behavior-gameplay`, ausgehend von `60f61e018e61a98824846d2bb020a0d6c1c18cb9`.

## Spielbarer Umfang

- **F halten:** Eine friedliche Kreatur ansehen und innerhalb von 6 m Vertrauen aufbauen. Freie Sicht ist erforderlich. Ohne Fähigkeit dauert die vollständige Befreundung 8 Sekunden; Offenheit erhöht den Aufbau um 15 % (rechnerisch etwa 6,96 Sekunden). Eine Unterbrechung erhält den bisherigen Fortschritt; die Handlung benötigt erneut F. Abgeschlossen: 3 Sozialpunkte, dauerhaft befreundetes Individuum und gemeinsame Speicherung.
- **H:** Innerhalb von 3,6 m Nahrung mit einem verletzten Tier teilen. Eine Versorgung kostet 12 eigene Sättigung; mindestens 22 müssen vorhanden sein. Sie heilt 30 Prozentpunkte der maximalen Tiergesundheit. Zusammenhalt erhöht dies bei Verbündeten auf 34,5 Prozentpunkte. Erst die vollständig beseitigte, unabhängig verursachte Not kann 2 Sozialpunkte vergeben.
- **Beißen:** Nutzt die bisherige Eingabe, Reichweite und Körper-Angriffswerte. Ein Biss kostet 12 von 100 Ausdauer. Nach 0,8 Sekunden ohne Biss erholen sich 15 Punkte je Sekunde, mit Ausdauer 17,25. Jagdinstinkt erhöht den tatsächlichen Schaden um 10 %. Ein gewonnener Konflikt mit einem feindlichen Tier oder eine abgeschlossene Jagd mit fleischfähigem Mund kann 3 Aggressionspunkte vergeben.
- Das HUD zeigt Beziehung, Vertrauen, Gesundheit, Ausdauer und verfügbare Handlungen. K öffnet den vorhandenen Skilltree; dort ist die Wirkung von vier Kreaturenknoten jetzt als aktiv beschrieben. Die zwei Vermächtnisknoten sind weiterhin für spätere Gruppenmechaniken vorbereitet.

Der kleine Versorgungsprototyp startet jedes fünfte friedliche Individuum, anhand seines stabilen Individual-Seeds, mit einer Umweltverletzung und 55 % Gesundheit. Das ist eine konkrete Punktequelle, keine bereits vorhandene Hunger-/Krankheits-/Räuber-Beute-Simulation. Externe Wildtierangriffe können ihren tatsächlichen Verursacher über `receive_creature_attack` übergeben; unbekannte oder selbst verursachte Not erzeugt keinen Hilfebeleg.

Befreundete Wildtiere wandern weiter und fliehen nicht mehr vor dem Spieler. Sie werden dadurch nicht automatisch Mitglieder der eigenen Spezies oder Nestgruppe. Nest, Gruppenmitglieder und Befehle wie Folgen/Warten/Heimkehren gehören zum separaten Kreaturverhalten-Chat.

## Belohnung und Speicherung

Die M2A-Regeln bleiben unverändert: getrennte Bestände, maximal 24 verdiente Punkte je Ast und Phase, höchstens eine Belohnung pro Individuum und pro Begegnung. Befreunden und anschließendes Helfen desselben Tieres zahlen deshalb nicht zweimal. Insight und Körperteilfreischaltungen bleiben unabhängig.

Eine neue Begegnung verwendet die vorhandenen Kampagnen-, Körper-, Regionen-, Spezies- und Objektkennungen. Die Kennung bleibt bei normalem Streaming mit gleichem Spawn-Slot erhalten. Gespeichert werden Beziehung, Vertrauen, Gesundheit, Verletzungsursache, erster Konfliktgrund, Tod und verbleibende Kadavernahrung. Unberührte Tiere erzeugen keinen Eintrag; höchstens 32.768 berührte Individuen werden pro Kampagne aufgenommen, ohne bestehende Einträge oder bezahlte Ziele zu verdrängen. Diese Grenze ist ein Schutz des Prototyps; für langfristige Galaxiekampagnen ist eine nach Körpern segmentierte Speicherung ein späterer Ausbau.

Abgeschlossene Begegnungen, Versorgung, Spielertreffer und Kadaververbrauch werden unmittelbar gemeinsam gespeichert. Teilweises Vertrauen und externe Verletzungen fordern Autosave an. Fehlgeschlagene Abschlüsse setzen Beziehung, Punkte und Ereigniszeiger zurück; fehlgeschlagene Versorgung gibt Sättigung zurück, fehlgeschlagene Treffer geben Ausdauer zurück und behalten die vorherige Gesundheit. Erfolgsereignisse werden erst nach erfolgreichem Schreiben veröffentlicht. Käufe oder weitere Kampagnenereignisse während dieses Schreibvorgangs werden abgewiesen.

Beim ersten Spielertreffer wird die Beziehung vor dem Angriff festgehalten. Verrat an Verbündeten wird auch nach späteren Angriffen oder Laden nicht zur belohnten Jagd. Ein vom Spieler verletztes Tier lässt sich in diesem Prototyp nicht wieder durch Helfen/Befreunden bewirtschaften. Nichtfleischfähige Spieler erhalten keine Jagdbelohnung für friedliche Beute. Die vorhandenen Effekte werden immer aus dem rohen Körperwert neu berechnet; Editorwerte werden nicht überschrieben.

Der gemeinsame Speicher steigt von Schema 4 auf **5**, Progression von 3 auf **4**, mit eigenem Begegnungsschema 1. Schema 1–4 bleibt lesbar. Migration bewahrt die Originaldatei und Entwürfe, IDs, Punkte und Käufe. Alte Spielstände bekommen keine rückwirkend erfundenen Beziehungen. Neuere/ungültige Verträge werden vor Überschreiben geschützt.

Die Tierposition ist weiterhin vom bestehenden Streaming abhängig. Diese Lieferung macht keine dauerhaft nachreisenden Begleiter oder vollständige Individualökologie daraus. Aggregierte Ökologieänderungen nach einem besiegten Tier werden im anschließenden Autosave erfasst; der individuelle Tod und seine Belohnung sind bereits im unmittelbaren Abschluss gespeichert.

## Zuständigkeiten und spätere Integration

Es wird kein unfertiger Fremdbranch zusammengeführt. PR #14 ist die veröffentlichte Basis; PR #9 und `main` bleiben ungemergt. Neuere Planeten-, Editor-, Menü-, Nestgruppen-, Sound- und Artenbucharbeiten gehören nicht automatisch zu diesem Testpaket.

Neue Implementierungen liegen in `creatures/behavior/`, `core/progression/creature_encounters.gd` und `core/progression/phase_progression_plan.gd`. Spieler/Tiere erhalten kleine Einbaupunkte für diese Komponenten. Im parallelen Editor-Branch insbesondere die beiden Wildlife-Skripte und Spieler-Einbaupunkte gezielt kombinieren, niemals Dateien vollständig ersetzen. Der Menübranch ändert ebenfalls den Speicherdienst: dessen Start-/Slot-/Pause-Regeln behalten und Schema-5-Validierung/Migration ergänzen. Beim Artenbuch die bestehenden Discovery-Felder und Ereignisse erhalten; `ui/discovery_journal.gd` und die bisherige Buchdarstellung wurden hier nicht weiterentwickelt.

Öffentliche Anschlüsse:

- `ProgressionService.get_creature_encounter(identity, role, seed)` liefert eine Kopie des persistenten Zustands oder den deterministischen Anfangszustand.
- `ProgressionService.store_creature_encounter(entry, immediate, outcome, context)` ist der gemeinsame Abschluss für diesen Laufzeitproduzenten. Es ist kein öffentlicher Punkte-Cheat; weitere Produzenten müssen Handlungsabschluss, Ursache, Reichweite und stabile Identität selbst belegen.
- `ProgressionService.get_phase_progression_preview(phase)` liefert Planung, tatsächlich vorhandenen Phasenbestand und berechnete Vermächtnisse, ohne etwas freizuschalten.
- `behavior_rewarded`, `behavior_node_purchased`, `campaign_event`, Spieler-`creature_attacked` und Tier-`health_changed`/`creature_defeated` stehen für späteres Audio oder Rückmeldung bereit. Erfolgsbenachrichtigungen einer Begegnung folgen dem gespeicherten Abschluss.

## Prüfung

`tests/creature_behavior_gameplay_test.gd` verwendet die echten Spieler-/Wildtierszenen. Es prüft Befreunden → verdiente Punkte → Kauf → messbar kürzere Befreundung, Hilfe und deren Kosten/Bonus, tatsächliche Angriffe/Ausdauer, Verrat, selbst verursachte Not, Pausen, Sichtblocker auch im Nahbereich, fehlgeschlagene Speicherungen, Streaming-Wiederkehr, getrennten Prozessneustart, alte/neue Speicherverträge sowie die Vorschau aller fünf Folgephasen.

`tools/review_behavior_gameplay.gd` prüft zusätzlich F/H/K und Maus-/Tastatureingaben in einem echten grafischen Godot-Fenster auf einer kontrollierten Testfläche. Es erzeugt fünf unveränderte Viewport-Aufnahmen. Bestehende Skilltree-Prüfungen und sechs Ansichten laufen weiterhin. Desktop-Exportprüfungen starten die unveränderte native Anwendung und führen den Verhaltenstest mit dem Editor gegen exakt ihre exportierte PCK aus; dies ist kein behaupteter grafischer Windows-Eingabetest.

Prüfstände und CI-Nachweise werden nach Abschluss in `validation/creature-behavior-gameplay.json` ergänzt. Der manuelle Spieltest auf dem Ziel-PC bleibt nötig für die Beurteilung von Tempo, Kampfgefühl und Leistung.
