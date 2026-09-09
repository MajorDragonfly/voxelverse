# Verhaltensfortschritt und Skilltree – M2A

Stand: 8. September 2026. Separater Arbeitszweig `agent/m2-behavior-skilltree`,
ausgehend von `555f9efa2a16d8dde6fbf121157671ef944b2f83` auf `agent/meta-runtime-v8`.
Vor der Bereitstellung auf `6e5c6d2d1db0de40d676c4ea85efb02c3cb5d4ae` aktualisiert;
dieser Zwischenstand ergänzt ausschließlich den M1-Abschlussbericht und Nachweise.

## Zuständigkeit und Integration

Dieser Chat übernimmt **M2A: Verhaltenspunkte, Skilltree-Regeln, Effekte und Speicherung**.
Der andere Roadmap-Chat führt M1 weiter. M2A wird über einen eigenen Pull Request
gegen `agent/meta-runtime-v8` integriert. PR #9 wird dafür nicht gemergt und `main`
wird nicht bearbeitet. Vor der Integration den dann aktuellen Zielbranch prüfen.

**M2 ist damit nicht vollständig:** Gemeinsame Editorverträge, expliziter Import
externer Entwürfe und die zugehörigen Undo-/Redo-Regeln bleiben M2B. Die endgültige
Skilltree-Oberfläche und echte Befreunden-/Helfen-/Konfliktabschlüsse gehören zum
spielbaren Kreaturenablauf M3/M4. Dieses Paket führt die Regeln mit gezielt
ausgelösten Spielereignissen durch die echten Kampagnen- und Speicherdienste aus.
Der bestehende Kampf erhält dadurch noch keine neuen Belohnungen oder Werte.

Berührte gemeinsame Dateien: `autoload/game_state.gd`, `autoload/progression_service.gd`,
`autoload/save_game_service.gd`, `core/campaign/game_event.gd`,
`tests/campaign_foundation_test.gd` und der M2-Eintrag in `ROADMAP.md`.
Die übrige Implementierung liegt in `core/progression/` und einem eigenen Test.

## Regeln des ersten Durchstichs

Sozial- und Aggressionspunkte werden getrennt nach Spielphase verdient und ausgegeben.
Insight und Körperteilfreischaltungen bleiben eigene Bestände. Es gibt keinen Zwang,
sich auf einen Ast festzulegen; beide Äste können vollständig gekauft werden.

| Abschluss in der Kreaturenphase | Punkte | Erforderliche Fakten vor der Handlung |
|---|---:|---|
| Befreunden | 3 sozial | Ziel war neutral oder wild |
| Helfen | 2 sozial | Ziel neutral, wild oder verbündet; Bedarf durch Umwelt oder Dritte entstanden |
| Gewonnener Konflikt | 3 aggressiv | Ziel war Beute oder feindlich; Anlass Jagd, Revierkonflikt oder Selbstverteidigung |

Das sind **vorläufige Prototypwerte**, keine fertige Spielbalance. Niederlagen,
Entdeckungen, Phasenwechsel, Klicks und Ereignisse ohne Abschlusskontext bringen
keine Verhaltenspunkte. Von Spieler oder Verbündeten erzeugter Hilfsbedarf wird
nicht belohnt. Der Produzent muss diese Fakten aus der Simulation ableiten.

Pro Phase wird ein dauerhaft identifiziertes Ziel höchstens einmal belohnt, auch
bei einer neuen Ereignissequenz, einem anderen Ergebnis oder nach Respawn. Auch
eine Begegnung kann insgesamt nur einmal Punkte liefern, selbst wenn mehrere
Ziele oder beide Verhaltensarten darin vorkommen. Diese konservative Regel kann
M4 um echte Aufgaben und sauber definierte Begegnungsabschnitte erweitern.

Der Prototyp begrenzt den Verdienst auf **24 Punkte je Ast und Phase**. Der letzte
Abschluss liefert höchstens den verbleibenden Rest. Ausgeben hebt diese Grenze
nicht auf. Alle drei Knoten eines Astes kosten zusammen 9 Punkte. Dadurch bleibt
die Belohnungshistorie ohne Löschen alter Sperren auf höchstens 48 Einträge pro
Phase begrenzt. Neue Belohnungsregeln für spätere Phasen sind ausdrücklich noch
nicht freigeschaltet. Die sechs Phasenbestände sind für deren Ausbau vorbereitet.

## Knoten und Effekte

| Ast | Knoten | Kosten | Voraussetzung | Wirkung |
|---|---|---:|---|---|
| Sozial | Offenheit | 2 | – | Befreunden +15 % in der Kreaturenphase |
| Sozial | Zusammenhalt | 3 | Offenheit | Unterstützung Verbündeter +15 % in der Kreaturenphase |
| Sozial | Gemeinsinn | 4 | Zusammenhalt | Gruppenkoordination +10 % ab der Stammesphase |
| Aggressiv | Jagdinstinkt | 2 | – | Angriffswirkung +10 % in der Kreaturenphase |
| Aggressiv | Ausdauer | 3 | Jagdinstinkt | Ausdauerregeneration +15 % in der Kreaturenphase |
| Aggressiv | Wehrhaftigkeit | 4 | Ausdauer | Gemeinsame Verteidigung +10 % ab der Stammesphase |

Diese Wirkungen sind als abgefragte Multiplikatoren implementiert und geprüft;
ihre Verbraucher in der Tierwelt/Gruppe werden in M3–M5 angeschlossen. Die
Katalogtexte sind für die spätere Oberfläche vorbereitet.

`calculate_effect()` berechnet den Wert immer aus ursprünglichem Körperfaktor,
Technikzuschlag und den gültigen gekauften Knoten. Der Prototyp begrenzt das
Ergebnis auf 0,5 bis 2,0. Beiträge und Begrenzung werden erklärbar zurückgegeben.
Ein bereits berechnetes Ergebnis darf nicht erneut als Körperbasis dienen.
Laden und Phasenwechsel addieren keinen Bonus in einen bestehenden Wert hinein.

Kreatureneffekte enden mit der Kreaturenphase. Vermächtnisse beginnen in der
darauffolgenden Phase und bleiben später wirksam. Unverbrauchte Kreaturenpunkte
können auch im Stamm für Kreaturenknoten eingesetzt werden. Ein erst dann gekaufter
Vermächtnisknoten wirkt sofort genau einmal. Umskillen ist noch nicht eingeführt.

## Schnittstellen

`ProgressionService` besitzt das Modell und bleibt Teil der Kampagnensicherung.
Öffentliche Abfragen liefern Kopien; Aufrufer können den Katalog oder Punktestand
dadurch nicht nebenbei verändern.

```gdscript
# Der Gameplay-Produzent bestätigt einen tatsächlich abgeschlossenen Vorgang.
var event = GameState.campaign.next_event(
    CampaignGameEvent.Kind.INTERACTION, stable_target_id,
    GameState.current_phase, "helped")
event.encounter_id = stable_encounter_id
event.behavior_context = {
    "target_relation": "ally",
    "need_origin": "environment",
}
GameState.record_campaign_event(event)

var wallet = ProgressionService.get_behavior_wallet(0)
var nodes = ProgressionService.get_behavior_nodes(0)
var result = ProgressionService.purchase_behavior_node("creature.social.approach")
var effect = ProgressionService.get_behavior_effect("befriend_efficiency", 0)
```

`stable_target_id` bezeichnet die dauerhaft wiedererkennbare Art, Kreatur oder
Aufgabe; `stable_encounter_id` denselben abgeschlossenen Vorgang auch nach Laden.
Keine Node-Instanznummern oder bei jedem Versuch frisch erzeugten IDs verwenden.
Für Konflikte lautet der zusätzliche Kontextschlüssel `conflict_reason`.
Alte M0-Ereignisse bleiben gültig, liefern ohne diesen Kontext aber keine Punkte.

`GameState` akzeptiert zuerst die geordnete Sequenz. Direkt anschließend verrechnet
`ProgressionService` das Ereignis, bevor `campaign_event` Beobachter benachrichtigt.
Ein dort ausgelöster Snapshot enthält daher sowohl die Sperre als auch die Punkte.
Direkte Übergabe eines noch nicht akzeptierten Ereignisses an den Fortschrittsdienst
wird abgewiesen. Punkte werden mit dem nächsten gemeinsamen Autosave gesichert.

Ein Kauf prüft Phase, Voraussetzungen, Bestand und bereits gekaufte Knoten und
schreibt dann sofort den gemeinsamen Snapshot. Scheitert das Schreiben, werden
Punkte und Knoten zurückgesetzt; es wird kein Kauferfolg signalisiert. Verschachtelte
Käufe während dieser Sicherung werden abgewiesen. Die Ergebnis-Dictionaries tragen
`ok` und im Fehlerfall einen maschinenlesbaren `reason`.

## Speicherung und Migration

Der äußere Spielstand steigt von Schema 3 auf **4**, der Fortschrittsbereich von
2 auf **3**; das Verhaltensmodell startet mit Schema und Regelversion 1. Alte M0/M1-
Programme erkennen damit den neueren Gesamtspielstand und blockieren dessen
Überschreiben, statt die neuen Punkte still zu verlieren.

Schema 1/2 nutzt weiterhin die Migration der ursprünglichen Kampagne einschließlich
separater Editor-Dateien. Bei Schema 3 bleiben Kampagnen-ID, Zeit, Ereignisse,
Standort, Entwurfs-IDs und der eingebettete Entwurfsbestand erhalten. Eine abweichende
lose Editor-Datei verdrängt den Snapshot nicht. Der alte Stand wird vor dem Import
als exakter Text mit seinen Entwürfen in einer unveränderten Migrationssicherung
erhalten. Vergangene Entdeckungen erzeugen keine rückwirkenden Verhaltenspunkte.

Verdiente und ausgegebene Beträge werden beim Laden gegen Belohnungsbelege,
Knotenpreise und Voraussetzungen geprüft. JSON-Zahlen werden nach erfolgreicher
Validierung wieder als ganze Punktzahlen geführt. Ein beschädigter Stand kann
aus dem vollständigen `.bak` wiederhergestellt werden. Unbekannte neuere
Speicher-, Fortschritts- oder Regelversionen blockieren Schreiben und stille
Rückstufung – auch wenn sie im Backup liegen. Änderungen an Knotenpreisen oder
Belohnungsregeln benötigen eine neue Regelversion mit gezielter Migration.

## Prüfung

**50/50 Prüfungen mit Godot 4.6.3 bestanden.** Dazu gehören Import, Quellenprüfung,
alle 25 Testskripte, Einstieg ins Planetenlabor, Hauptszene, 18 gezielte
Beendigungsszenarien und die bestehende Streaming-Messung. Der M2A-Nachweis ist
eine technische Prüfung; eine fertige Skilltree-Bedienoberfläche ist nicht enthalten.

`tests/behavior_progression_test.gd` prüft Punkte und beide Äste, Voraussetzungen,
gemischte Käufe, Punktelimits, Wiederholungen und Respawn, selbst erzeugten Hilfsbedarf,
Beobachter-Snapshots, vollständigen Rücklauf bei Schreibfehlern, Migration aus Schema 3,
beschädigte/neue Versionen, späte Käufe sowie beide Vermächtnisse nach Phasenwechsel.
Ein zweiter Godot-Prozess lädt dieselbe Sicherung und prüft IDs, Punkte, Sperren
und Knoten unabhängig vom Arbeitsspeicher des ersten Prozesses.

Der bestehende M0-Test deckt weiter Schema 2 mit Kreatur, zwei Gebäuden und zwei
Planeten ab. Die hier ausgeführten Linux-Prüfungen laufen über
`tools/validate_godot.py`: Der Runner isoliert dort `user://` über `XDG_DATA_HOME`.
Die Tests schreiben Entwurfsdateien und benötigen diese Isolation; ein direkter
Testaufruf mit dem persönlichen Godot-Benutzerverzeichnis ist nicht vorgesehen.
Die abschließenden maschinenlesbaren Ergebnisse stehen in `validation/m2-behavior.json`.
