# ARCH-28 – bestätigte Epochenübergabe

Stand: 10. September 2026. Auftrag: ARCH-28 / bestehender M5 → M6-Wechsel. Gemeinsame Basis: `ea900f2e09946660694a9e59399b4680a5655a85` auf `main`. Branch: `agent/arch28-phase-handoff-2026-09-10`.

## Umfang und Anschluss

Die vorhandene Kreaturen- → Stammesphase verwendet jetzt einen expliziten Übergabeanschluss. Dies ist die erste spielbare Epochenübergabe aus ARCH-28; weitere Epochen werden nicht freigeschaltet. Die nachfolgende Modulregistrierung aus ARCH-07 bleibt beim Speicherstrang. Dieses Paket benötigt keinen neuen Save-Teilnehmer: Es verwendet weiterhin dessen vorhandene vollständige Snapshot-Validierung und atomare Dateiablösung.

| Besitzer / Datei | Verantwortung |
|---|---|
| `core/campaign/phase_handoff.gd` | Statische Liste tatsächlich spielbarer Adapter, sequenzielle Voraussetzungen, bestätigte Vorbereitung in einer unabhängigen Kampagnenkopie, Bestandserhalt, unveränderter Ereignis- und Abschlussbeleg. Keine eigene Persistenz oder Laufzeitinstanz. |
| `world/tribe/tribal_phase_handoff.gd` | Einziger registrierter Adapter: 0 → 1. Liest die vorhandene bestätigte Dorfvorbereitung, prüft sie mit `TribeState.validate` und fügt sie dem Kandidaten hinzu. Ein schon gespeichertes Dorf wird niemals ersetzt. |
| `GameState.get_phase_transition_blockers` | Bestehender Leseanschluss für UI und Fortschritt; delegiert an denselben Übergabeanschluss wie der Schreibbefehl. |
| `SaveGameService.request_phase_transition` | Bestehender Schreibbefehl einschließlich Sperre gegen Wiedereintritt, gemeinsamem Writer und vollständiger Rücknahme bei Fehler. Emitiert `phase_changed` und das Kampagnenereignis erst nach erfolgreichem Commit. |
| Vorhandener `TribeController` / `TribePanel` | Unverändert: tatsächliche Wege/Fundamente, pausierter Bestätigungsdialog und an Kampagne/Körper/Spieler/Heimgruppe gebundenes Token. Nach Commit beziehungsweise Laden werden dieselben Bewohner und die Gruppensteuerung erst bei bereiter Bodenkollision/Navigation aktiviert. |

`prepare(state, target, token)` liefert entweder `{ok: false, code, message}` oder `{ok: true, code: "prepared", from, to, campaign, event}`. Die vorbereitete Kopie verändert weder lebende Figuren, Kamera, Punkte noch die gespeicherte Kampagne. Nur der SaveService übernimmt sie. Der konkrete Stammesadapter prüft Herkunft, Spezies, Fraktion, Bewohner und Ortsdaten über den vorhandenen Fachvalidator. Der bestehende `Civilization.validate_retention` schützt zusätzlich sämtliche bisherigen Kampagnenfelder einschließlich unbekannter Erweiterungen und besuchter Körper.

Save 9, GameState 4, Kampagne 3 und Stammesformat 5 (historischer Prüfstand) / 6 (Kugelwelt) bleiben unverändert. Die bestehende `Ids.scoped("transition", campaign_id, "0:1")` und das Belegformat mit `confirmed`, `tribe_id` und `body_id` bleiben erhalten. Keine neuen Tier-, Bewohner-, Arten-, Körper- oder Phasen-IDs entstehen durch den Umbau. Bereits abgeschlossene Stämme werden über den vorhandenen Ladeweg wiederhergestellt; sie durchlaufen keine zweite Vorbereitung.

## Erweiterungsregel

Neue Zielphasen erhalten erst nach einer vollständig spielbaren und geprüften Phase einen festen Adaptereintrag. Eine Enum-Zahl, ein Punktestand oder gespeicherte Verfügbarkeitsflags reichen nicht aus. Für Mittelalter und Neuzeit bleiben die vorhandenen fachlichen Sperrtexte bestehen. Die getrennten historischen `debug_prepare_phase_transition`-/`resume_phase_transition`-Prüfeinstiege wurden nicht verändert; sie sind keine reguläre Epochenfreigabe.

Ein späterer Adapter braucht Voraussetzungen, eine ausdrückliche Bestätigung, einen validierten Datenkandidaten mit Erhaltungsnachweis und den Anschluss der Zielsteuerung an den bereits gespeicherten Abschluss. Writer, Rücknahme, Ereignisbeleg und Speicherabschluss bleiben gemeinsam. Neue Speicherteilnehmer sind zuvor mit ARCH-07 zu integrieren.

## Prüfungen

- `phase_handoff_test`: echte bestehende Spieler-/Heimat-/Navigations-/Dialoginstanzen im historischen lokalen Prüfstand; Vorbereitung verändert weder Quelle noch Disk, Kandidaten besitzen keine geteilten Dorfbestände, ungültige Bewohner und vorhandenes Dorf werden abgelehnt. Veraltetes Token, Phasensprung, paralleler Übergang und Wiedereintritt beim Writer liefern keinen zweiten Commit. Schreibfehler bewahrt vollständige Kampagne, Punkte, Disk und Einzelsteuerung; derselbe gültige Dialog kann anschließend erfolgreich abschließen. Signalbeobachter lesen den bereits dauerhaft gespeicherten Abschluss. Doppelklick und unimplementierte Zielphasen bleiben gesperrt. Ein separater Godot-Prozess lädt denselben Stand zweimal und stellt anschließend dieselben drei Bewohner und die Gruppenkamera wieder her.
- `campaign_foundation_test`: bestehende Neu-/Altstandsmigration, Ereigniseinmaligkeit, gemeinsame Entwürfe, Savefehler und historische Debug-Unterbrechungswiederaufnahme.
- `tribal_progression_test`: bestehende Fortschritts-, Identitäts- und Erhaltungsverträge sowie harte Sperren späterer Epochen.
- `spherical_gameplay_test`: vorhandene reale Kugelwelt mit Heimat, bestätigtem Aufstieg, radialer Gruppensteuerung, Aufträgen/Fracht, Ursprungskorrektur, Save/Load, D1/D2/D3 und separatem Neustartprozess. Bestanden in 334,150 Sekunden, einschließlich frischem Prozess und anschließend zwei tatsächlich eingelagerten Milcheinheiten.
- Frischer Godot-Import, Art-Quellen und `tools/localization/catalog.py --check`.

Reproduktion mit Godot 4.6.3:

```bash
python tools/validate_godot.py --godot /path/to/godot --tests phase_handoff_test campaign_foundation_test tribal_progression_test spherical_gameplay_test --skip-main --output /tmp/arch28
python tools/localization/catalog.py --check
```

Die gezielten Prüfungen sind Linux/Headless-Nachweise. Sie sind keine optische Abnahme, Windows-Exportprüfung oder Ziel-PC-/FPS-Zusage. Der bestehende Prüflauf entdeckt die neue Datei über `*_test.gd`; CI-Dateien des parallel laufenden ARCH-29-Pakets werden nicht geändert.

## Integration

Gemeinsame Schreibbereiche: ausschließlich neuer Preload und `get_phase_transition_blockers` in `autoload/game_state.gd`, neuer Preload und `request_phase_transition` in `autoload/save_game_service.gd`. ARCH-23 ändert dort andere Speicher-/Bauplanfunktionen; gemeinsam nacheinander integrieren und betroffene Speicherprüfungen erneut laufen lassen. Produktions-, Tierkatalog-, Geometrie-, Populations-, Sprach- und Messdateien bleiben bei ihren Fachpaketen. Keine fremden unfertigen Änderungen werden übernommen.

Roadmap und gemeinsame Arbeitsverteilung bleiben beim dokumentierten Integrationsbesitzer. Dieser Übergabebericht ordnet die Lieferung ARCH-28 zu; `main` wird durch das Fachpaket nicht automatisch verändert. Exakte Quellrevision, Prüfzeiten und Abschlussstatus werden in `ARCH28_VALIDATION.json` festgehalten.

## Abschlussstatus

Die vier gezielten Godot-Prüfungen sind bestanden (Übergabe 7,767 s; Kampagnengrundlage 2,679 s; Stammesfortschritt 1,218 s; reale Kugelkette 334,150 s). Import, Art-Quellen und Sprachkatalog sind ebenfalls erfolgreich geprüft. Der geprüfte Implementierungscommit ist `1e59c850861c427d53134a98e8bd37c5a9dacfd8`; der nachfolgende Dokumentationscommit enthält ausschließlich diese Ergebnisse.

Die automatische Freigabeprüfung verlangte zunächst eine ausdrückliche Veröffentlichungsfreigabe für das GitHub-Ziel. Lars hat anschließend den Push dieses fertigen Fachbranches nach `MajorDragonfly/voxelverse` und die Erstellung eines Entwurfs-PR ausdrücklich freigegeben. Die Integration nach `main` bleibt ein separater Schritt.
