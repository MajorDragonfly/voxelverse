# Erste Schritte in Voxelverse

Menü-Branch `agent/game-menus`, 9. September 2026.

Neue Abenteuer erhalten eine kleine Einführung am unteren linken Bildschirmrand. Vier Grundlagen werden durch tatsächlich ausgeführte Aktionen erkannt: ungefähr 32 Grad mit der Spielkamera umschauen, vier Meter selbst gesteuert zurücklegen, vom Boden abspringen und eine Kreatur im Scanmodus vollständig scannen oder eine bereits bekannte Art anvisieren. Die Reihenfolge ist frei. Bereits erledigte Aufgaben müssen nicht wiederholt werden; die Karte zeigt jeweils die erste offene Aufgabe.

Die Hinweise verwenden die aktuell gespeicherten Tastenbelegungen. Beim Scannen unterscheiden sie zwischen dem Öffnen des Modus und dem Halten des Tiers im Fadenkreuz. Die vorhandenen situationsabhängigen Hinweise für Kreaturen, Nahrung und Wasser bleiben an denselben Spielaktionen angeschlossen. Die Einführung ist eine Ergänzung der vorhandenen Hilfe.

Über **Esc → Erste Schritte** lassen sich alle Aufgaben nachlesen, die Einführung überspringen oder neu starten. Die Welt bleibt während der Hilfe pausiert. Überspringen und Neustarten schließen die Pause und geben die bisherige Steuerung zurück. Neustarten setzt ausschließlich die Einführung zurück. Beim Abschluss erscheint eine kurze Bestätigung; die Hilfe bleibt danach verfügbar.

## Fortschritt und ältere Spielstände

`SaveGameService.guidance` hält den unabhängigen Zustand aus `core/onboarding_progress.gd`. Das optionale Snapshotfeld `onboarding` enthält Schema 1, den Überspringen-Status und den Teilfortschritt aller vier Aufgaben. Der bestehende Kampagnensnapshot bleibt Schema 4. Reguläres Speichern, Kopieren und Wiederherstellen sichern diesen Zustand zusammen mit der Kampagne.

Auch Teilstrecken und eine teilweise erfüllte Kamerabewegung bleiben nach dem Speichern erhalten. Neue abgeschlossene Aufgaben planen eine automatische Speicherung nach zwei Sekunden. Überspringen und Neustarten planen sie nach 0,2 Sekunden; das vorhandene Speichern beim Verlassen des Spiels bleibt wirksam. Eine erzwungene Beendigung vor dem nächsten erfolgreichen Speichern kann den noch ungespeicherten Teilfortschritt verlieren.

Ältere Spielstände ohne `onboarding` werden ohne aktive Einführung geladen; sie kann freiwillig über die Hilfe gestartet werden. Fehlerhafte optionale Einführungsdaten werden defensiv eingelesen. Daten einer neueren Einführungsversion werden unverändert im Snapshot erhalten; ihre Fortschrittsbearbeitung bleibt in dieser Version deaktiviert, während die Hilfe und die Kampagne weiter verfügbar sind.

## Aktionsnachweise und Integrationsstellen

- `creatures/player/player_controller.gd` meldet `guidance_action(action, value)` nach tatsächlich angewandter Kameradrehung, nach horizontaler Bewegung mit Bewegungseingabe und nach einem erfolgreichen Absprung mit Aufwärtsbewegung. Fallen, Landen, reine Tastendrücke vor einem Hindernis und Aufsteigen im Wasser erfüllen die Sprungaufgabe nicht.
- `creatures/player/creature_scanner.gd` meldet Untersuchung erst nach abgeschlossenem Scan oder beim Anvisieren einer bereits bekannten Art. Das bloße Einschalten des Modus reicht nicht aus.
- `ui/frontend/first_steps.gd` bindet die Signale des jeweils aktiven Spielers an die Einführung. Die Karte und ihre Fortschrittsannahme sind auf die aktive Kreaturenphase beschränkt. Während Pause, Laden, Tod sowie in Titel, Editor und Planetenlabor wird kein Einführungsfortschritt erfasst.
- `autoload/session_flow.gd` installiert die Karte und bietet den Zugang zur Hilfe im Pausemenü. Die Karte nimmt keine Mausereignisse entgegen.

Die Einführung selbst erzeugt keine zusätzlichen Kampagnenereignisse, Belohnungen, Skilltree-Punkte oder Entdeckungen. Die Einführung nutzt die bestehenden Spieler- und Untersuchungsfunktionen. Bei späterer Integration der anderen Arbeitszweige sind die beiden kleinen Signalanschlüsse im Spieler und im Scanner zu übernehmen.

## Abnahme

`tests/onboarding_test.gd` prüft Teilfortschritt, beliebige Reihenfolge, Überspringen, Neustarten, echte Speicherdateien, unabhängige Kopien, ausgewählte Sicherungen sowie alte, beschädigte und zukünftige optionale Einführungsdaten. `tools/validate_export.py` prüft denselben Vertrag am exportierten Release-PCK.

Die Frontend-Diagnose verwendet echte Viewport-/Input-Ereignisse für Pausenhilfe, Überspringen, Neustarten, neu belegte Bewegungstasten, Sprung und Untersuchung. Für die Bewegungs- und Sprungprüfung wird vorübergehend ein unsichtbarer Physikboden eingefügt, damit prozedurale Küsten und Terrain-Streaming nicht über den Test entscheiden. Die Untersuchung nutzt eine echte erzeugte Kreatur mit ihren vorhandenen Daten. Nach den Scan- und Buchaufnahmen werden der Physikboden entfernt und Spielerposition und Kamera zurückgesetzt. Der Headless-Treiber kann den Mauszeiger nicht erfassen; die vollständige Kamerabewegung wird deshalb im grafischen Lauf geprüft.

Die Frontend-CI erwartet insgesamt 17 Aufnahmen, darunter `first_steps`, `first_steps_help`, `first_steps_jump` und `first_steps_complete`, `scan_progress`, `scan_known` und `scan_journal`. Veröffentlichte Prüfresultate und die Integrationsgrenze der parallelen Arbeitszweige stehen in [PR #16](https://github.com/MajorDragonfly/voxelverse/pull/16).
