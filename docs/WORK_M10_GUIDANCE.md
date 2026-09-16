# M10-GUIDANCE · Vom Erkunden zum ersten Stamm

Basis: `d57b1ef385728728b132518a1ea05683888dcae0` (`agent/playtest-latest-20260915`, PR #125).
Branch: `agent/m10-guidance-20260916`. Fachpaket, kein Merge und keine Gesamtfreigabe.

## Spielergebnis

Die optionale Einführung umfasst vier frei wählbare Kapitel mit neun Übungen:
Erkunden (Umschauen, Laufen, Springen, Scannen), Versorgen (Essen, Trinken),
Zusammenleben (Heimat, Gefährtenbefehl) und Stamm gründen. Esc → Erste Schritte
zeigt ausführliche Hilfe und aktuelle Hinweise, erlaubt Kapitelwahl, Neustart
und Ausschalten. Spieler müssen die Übungen nicht in Reihenfolge erledigen.
Die bestätigte Stammesgründung beendet die Einführung auch bei offenen Übungen;
diese erhalten keine erfundenen Häkchen. Der Stammes-HUD übernimmt anschließend.

Hinweise sind auf Deutsch und Englisch verfügbar. Belegbare Bewegungs- und
Interaktionstasten werden live gelesen; das Heimatmenü verwendet den vorhandenen
festen N-Anschluss. Für das Entdeckungsbuch wird auf den HUD-Knopf verwiesen,
so dass PR #134s neue Menübelegungen keine widersprüchliche J-Anweisung erzeugen.

## Verträge

- `OnboardingProgress` Schema 2 bleibt der bestehende optionale SaveParticipant.
  Neu sind zusätzliche Übungswerte und `focus`. Keine neue Datei, Währung,
  Belohnung, Art-/Gruppen-ID oder Pflichtvoraussetzung für den Aufstieg.
- Teilweise erledigtes Schema 1 wird verlustfrei übernommen. Bereits fertige oder
  übersprungene alte Einführungen bleiben still. Fehlende Legacy-Daten bleiben
  ausgeschaltet. Zukünftige Versionen (auch 2.5) bleiben unverändert und inaktiv.
- Nahrung zählt bei tatsächlich gestiegenem Hunger im gemeinsamen Spieler-
  Verbraucher; dadurch sind endliche Beerenpflanzen und `consume_food` abgedeckt.
  Trinken zählt nach der vorhandenen Prüfung erreichbaren Süßwassers.
  Laden und Wiederbelebung setzen Bedürfnisse direkt und erzeugen keine Häkchen.
- Heimat wird höchstens zweimal je aktiver Spielsekunde aus dem validierten
  kanonischen Heimatbestand gelesen. Gespeicherte Folgen-/Heimkehren-Befehle
  lassen sich beim Laden wiedererkennen. Das neue `order_committed`-Signal kommt
  erst nach erfolgreicher Speicherung, auch bei bewusstem Befehl im Pausenmenü.
- Die Einführung ruft niemals `prepare_confirmation`, `confirmed_handoff` oder
  einen Phasenwechsel auf. Die letzte Übung zählt erst in Phase 1 mit aktivem,
  vom bestehenden Stamm-Controller geprüften Dorf.
- Titel, Laden, Pause, Tod und Scanner verdecken die Karte; pausierte/dead player
  Bewegung zählt nicht. Explizite Gruppenbefehle im pausierten Heimatmenü zählen.
- Hilfe ist scrollbar; die Karte beansprucht keinen Mausfokus. Ein Sprachwechsel
  aktualisiert eine bereits geöffnete Hilfe. Kapitel-/Übungsmengen sind begrenzt.

## Integration

Eigene Dateien: `core/onboarding_progress.gd`, `ui/frontend/first_steps.gd`,
`ui/frontend/guidance_text.gd`, Onboarding-Tests und dieser Nachweis.
Gemeinsame kleine Anschlüsse: Spieler (`restore_hunger`, `_try_drink_water`),
Heimat-Controller (`order_committed`), Übersetzungskatalog mit generierten PO-Dateien,
Testregistrierung in `frontend_locale`.

PR #133 berührt ebenfalls `player_controller.gd`, aber andere Abläufe. Beim
Zusammenführen beide Funktionen erhalten und auf dem neuen Merge-Tree prüfen.
Katalog-/Testlisten mit parallelen Paketen additiv vereinigen; PO-Dateien aus dem
vereinigten Katalog regenerieren. Zentrale Status-/Backlog-Dateien bleiben beim
Integrationschat.

## Abnahme

Die ausführbare Weltprüfung startet den normalen Kugel-Spielweg und benutzt
endliche Pflanzen, echtes Süßwasser, Heimat-/Befehlstransaktionen und den
bestehenden Bestätigungsdialog. Sie prüft Fehler-Rollback, echte Speicherung,
Kopie und einen frischen Godot-Prozess. UI-Geometrie wird in zwei Sprachen,
800×600/1280×720 und 100/150 % Textgröße geprüft. Der vorhandene HUD-Test prüft
die übrigen gemeinsamen Verbraucher.

Ein erfolgreicher Prozess-Exit allein ist kein Vollständigkeitsbeleg: Die Logs
müssen den abschließenden Testmarker enthalten. Kopflose Tests sind keine native
Windows-/Export-/FPS-/gerenderte Sichtfreigabe.

Abgeschlossen: vier gezielte Tests mit vollständigen Abschlussmarkern, einschließlich
frischem Prozess, plus Import-/Quellenprüfungen. Alle neun Karten wurden in 72
Sprach-/Auflösungs-/Textgrößenkombinationen geprüft. Befehle, Umgebung, sauberer
Quell-Tree, unveränderte Logs und Grenzen: [evidence/m10-guidance](../evidence/m10-guidance/README.md).
