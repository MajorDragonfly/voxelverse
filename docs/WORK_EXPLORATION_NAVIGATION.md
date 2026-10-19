# Erkundung und Navigation

NAV-01-EXPLORATION erweitert die integrierte Weltkarte und Minimap. Der reguläre Einstieg bleibt die Kugelkampagne.

## Bedienung

- Weltkarte mit der belegten Kartentaste öffnen, standardmäßig **M**.
- Rechtsklick auf bereits erkundetes Gelände setzt einen persönlichen Wegpunkt. Unter **Wegpunkte** lassen sich die eigene Position und die Kartenmitte merken.
- Wegpunkte auswählen, benennen, als Ziel verfolgen oder löschen. Es gibt bis zu 24 Wegpunkte je Himmelskörper.
- Einen bekannten Ort aus dem vorhandenen Ortsregister auswählen und **Ziel setzen** drücken, um etwa das eigene Nest oder die Heimat wiederzufinden.
- Die Minimap zeigt das aktive Ziel mit Namen, Entfernung und Richtung. Bis sechs Meter Abstand erscheint „Angekommen“. Das Ziel bleibt bis zur nächsten Auswahl oder bis **Zielverfolgung beenden** erhalten.
- Im Stammesmodus beginnt die Zielanzeige bei einem ausgewählten geladenen Bewohner, sonst beim ersten geladenen Bewohner. Kameraschwenks ändern dessen Entfernung zum Ziel nicht.
- Pfotensymbole auf der Minimap zeigen eigene lebende gezähmte Tiere. Wildtiere, begonnene Zähmversuche, tote Tiere und Tiere anderer Fraktionen werden nicht angezeigt.
- Ein Klick auf die Zielanzeige der Minimap öffnet die Wegpunktverwaltung. Esc verlässt zunächst ein Textfeld oder die Verwaltung und schließt danach die Karte.

Die Richtungslinie ist kein geprüfter Gehweg und steuert weder Kreatur noch Bewohner. Kartenbewegung und Wegpunkte erkunden kein Gelände.

## Speicherung

`core/map/navigation_state.gd` besitzt den optionalen Körperabschnitt `map_navigation` im bestehenden Kampagnen-Snapshot. Alte Spielstände benötigen keine Migration. Namen, stabile IDs und Zielwahl werden gemeinsam mit dem Spielstand gespeichert. Die Oberfläche nimmt eine abgewiesene Speicherung vollständig zurück. Ein unbekanntes zukünftiges Navigationsformat bleibt über den zentralen SaveParticipant geschützt, auch in einem gerade nicht besuchten Körper.

Bekannte Ziele speichern nur die bestehende Orts-ID und werden durch den Atlas und die aktuellen Freundschaftsdaten aufgelöst. Tiermarker lesen das vorhandene D2-Register und bei geladenen Tieren deren aktuelle Position. Es gibt keinen zweiten Erkundungs-, Besitz- oder Simulationsschreiber.

## Prüfung

- `navigation_state_test`: Grenzen, unbekanntes Gelände, stabile IDs, Namen, JSON, fremde Körper, ungültige Daten, Versionsschutz und Tierfilter.
- `navigation_world_test`: öffentlicher Kugelstart, Maus/Tastatur, DE/EN bei 800×600/1280×720/1920×1080 und 100/150 %, abgewiesene Speicherung, Minimap, frischer Prozess und echte A-B-A-Reise.
- Bestehende Karten-, Minimap-, Lokalisierungs-, Atlas- und SaveParticipant-Verbraucher bleiben eigenständige Regressionstests.
- Für native Bilder: `godot --path . --rendering-method gl_compatibility --script res://tests/navigation_world_test.gd -- --ui-only --ui-fixture --capture /absoluter/pfad`. Die native Layoutprüfung verwendet die produktiven Spieler-/Kartenoberflächen in einer begrenzten Testszene. Unter Linux ist dafür ein Display erforderlich. Der reguläre Test ohne diese beiden Diagnoseflags startet die echte Kugelkampagne und führt die vollständige Reise aus.

Die tatsächlich ausgeführten Prüfungen und der genaue Quellenstand stehen im Liefer-PR. Ein Software-Rendererlauf ersetzt keine FPS- oder Spielkomfortabnahme auf dem Ziel-PC.
