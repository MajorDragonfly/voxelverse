# ARCH-25: Nachbarstamm-Ansicht DE/EN

Stand: 10. September 2026. Ausgangspunkt: veröffentlichter `main` `ea900f2e09946660694a9e59399b4680a5655a85`.
Branch: `agent/arch25-neighbor-localization-2026-09-10`. Bezug: [ARCH-25](ARCHITECTURE_BACKLOG.md#arch-25--fachresultate-und-darstellung-trennen), Designvorgabe 1.0.

## Umfang und Zuständigkeit

Abgeschlossenes Teilpaket: der vorhandene Reiter **Nachbarn**, alle eigenen Kontakt-/Hilfsrückmeldungen und die gemeinsame Auswahl-/Pausezeile. Leere Ansicht, laufende Lieferung, Unterkunftsbau, freundlicher Abschluss, Buttons und Hilfetext sind in Deutsch und Englisch verfügbar. Die gesamte Dorfverwaltung ist damit noch nicht übersetzt.

ARCH-20 (Ressourcen/Produktion) und ARCH-23 (Baupläne) werden in anderen Chats bearbeitet. Dieses Paket ändert weder deren Arbeitsdateien noch SaveGameService, TribeController, Baupläne, Produktionskataloge oder gespeicherte Formate. Keine fremden unfertigen Änderungen übernommen. Roadmap und gemeinsame ARCH-Statuspflege bleiben bei der Integration; ARCH-25 insgesamt bleibt offen.

## Datenbesitzer und Anschluss

| Bereich | Autoritativer Besitzer / Port | Darstellung |
|---|---|---|
| Nachbarfraktion, Bewohner, Bestände, Hilfsfracht und Lieferbelege | Aktiver Kampagnenkörper `tribal_neighbor`; bestehende Regeln in `neighbor_state.gd` | `progress()` liefert nur Fakten und kopierte Mengencontainer |
| Kontakt / Hilfsauftrag | `neighbor_runtime.gd`, bestehende Navigation und gemeinsame Save-Transaktion | `contact_result()` / `start_aid_result()` liefern `{ok, code, params}` |
| Start der Hilfsarbeit | `neighbor_state.begin_result()` | Fehlerkennung statt deutscher Fachmeldung |
| Laufende Rückmeldung | Flüchtiges `neighbor_runtime.last_result`; `controller.status` enthält den zugehörigen Code | `neighbor_presentation.gd` ordnet Codes dem gemeinsamen LocaleManager-Katalog zu |
| Sprache / Auswahl | LocaleManager als Gerätepräferenz; Auswahl weiterhin im TribeController | Bestehende Controls werden aktualisiert, nicht ersetzt |

Der bestehende `begin()`-Port liefert weiterhin einen leeren String bei Erfolg, sonst jetzt die stabile Fehlerkennung. `contact()` und `start_aid()` behalten ihre booleschen Rückgaben. `progress().met` bleibt für Save-Prüfung und Fortschritt erhalten; der einzige Verbraucher von `progress().text` war der Nachbarreiter und verwendet nun den Presenter. Für neue Verbraucher sind die strukturierten Ports maßgeblich. Die Datenformate bleiben Nachbar-Schema 3 bzw. Legacy 2; kein Speicherschema wurde geändert.

Die bekannten Codes stehen vollständig in `NeighborPresentation.RESULT_KEYS`. Parameter werden einmal eingesetzt; Namen wie `Beenden {count}` bleiben unverändert. Unbekannte Resultate zeigen eine lesbare Ersatzmeldung, keine interne Kennung. Rückmeldungen werden nicht gespeichert, und ein Sprachwechsel erzeugt weder einen Fachbefehl noch eine Schreiboperation. Andere Gruppenbefehle behalten ihre bisherigen Rückmeldungen und können kein altes Nachbarresultat erneut anzeigen.

## Nachweise

[Prüfergebnisse](evidence/arch25/checks.json):

- Import, Quell-Assetprüfung, bestehender Nachbarvertrag und Fernsimulation bestanden.
- Bestehender Sprachverwaltungs-Test bestanden.
- Neuer `neighbor_localization_test`: 166 Prüfungen im abschließenden Headless-Lauf, 158 im Renderlauf (anschließend um acht JSON-Anzeigeprüfungen ergänzt); beide Sprachen, alle Resultate/Zustände, literal erhaltene Namen, reine Lesedaten, unveränderte Datei, Auswahl, Fokus, Tab, Scrollposition und Pause. Echte Controls in einer ausdrücklich isolierten UI-Prüfansicht; keine nachgebaute Produktoberfläche.
- Erweiterter `tribal_neighbors_world_test`: physische Abholung, Anhalten, anderer Auftrag mit echter Rücklieferung, blockierter Träger, fertige Unterkunft und einmalige Belohnung, frischer Prozess und Slotkopie. Zusätzlich stabile Fehlerkennungen bei fehlgeschlagenem Speichern sowie DE/EN-Wechsel während realer pausierter Fracht geprüft. Finaler Lauf: 33,435 Sekunden, bestanden.
- Native OpenGL-Darstellung unter Linux/Xvfb bei 1920×1080, 1280×720 und 800×600, jeweils 100/150 %, DE/EN. Alle 14 Aufnahmen erzeugt. Bei 800×600/150 % sind Aktionen vertikal scrollbar; der Test prüft jede Aktion nach dem Scrollen vollständig im sichtbaren Bereich. Keine Aussage über Ziel-PC-Leistung.
- Die neuen Tests werden von der bestehenden allgemeinen Quelltest-CI automatisch gefunden.

Reproduktion nach Projektimport:

```bash
python tools/localization/catalog.py --check
python tools/validate_godot.py --godot /path/to/godot --skip-main --tests neighbor_localization_test localization_test tribal_neighbors_contract_test tribal_neighbors_world_test far_simulation_test --output /tmp/arch25-checks
xvfb-run -a -s '-screen 0 1920x1080x24' python tools/review_neighbor_localization.py --godot /path/to/godot --output /tmp/arch25-render
```

Vier repräsentative Aufnahmen: [Deutsch 1080p](evidence/arch25/neighbor-de-1920x1080-100.png), [Englisch 720p](evidence/arch25/neighbor-en-1280x720-100.png), [Deutsch 800×600/150 %](evidence/arch25/neighbor-de-800x600-150.png), [dieselbe Ansicht zu den Aktionen gescrollt](evidence/arch25/neighbor-de-800x600-150-actions.png). Der zusätzliche Reiter „Fixture“ kennzeichnet ausschließlich den Prüfstand; die Produktansicht bleibt im bestehenden Dorfpanel.

## Weiter offen

- Weitere ARCH-25-Pakete: gemeinsame Dorfkopfzeile, Aufträge/Berufe/Tierhaltung, übriges HUD/Buch und Editor. Die alten deutschen Validator-Diagnosen bleiben vorerst erhalten.
- Gemeinsame Ressourcensymbole nach dem veröffentlichten ARCH-20-Katalog anschließen; hier wurden keine konkurrierenden Ressourcenkennungen oder Icons eingeführt.
- Die allgemeine Gruppenbefehlsrückmeldung außerhalb von Nachbaraktionen ist weiterhin ein bestehender Legacy-String. Ihre Umstellung gehört in das nächste klar begrenzte Dorfpaket.
- Gemeinsamer Integrationslauf mit ARCH-20/23 und Ziel-PC-Abnahme stehen aus. Dieses Teilpaket behauptet weder eine vollständige Spielübersetzung noch die Fertigstellung aller ARCH-25-Punkte.
