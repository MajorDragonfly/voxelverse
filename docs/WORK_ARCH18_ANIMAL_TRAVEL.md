# ARCH-18 – gehaltenes Nutztier bei Planetenwechsel

Stand: 10. September 2026. Teilauftrag **ARCH-18 / ARCH-16**, echte D1/D2/D3-Kette bei A → B → A und frischem Prozess. Basis ist `main` `ea900f2e09946660694a9e59399b4680a5655a85`. Branch: `agent/arch18-animal-travel-2026-09-10`.

## Abgrenzung

Die bestehende Körperreiseprobe belegt Bewohner und Materialfracht. Die Fernmilchprobe verwendet dagegen einen begrenzten D2-Leseport-Prüfstand. Dieser Teilauftrag verbindet erstmals das tatsächlich gezähmte, physisch zum Tierplatz geführte und versorgte D1-Tier der gemeinsamen Kugelkampagne mit dem bestehenden Reiseweg.

ARCH-01/02/05/17/20/23/24/25/28 und die Weltkartenübersetzung bleiben bei den anderen Chats. ARCH-29 wurde in diesem Chat zuvor als PR #53 geliefert. Keine fremden unfertigen Änderungen werden übernommen; kein neuer Tierbesitzer, keine zweite Produktionskette, kein zusätzliches Saveformat. Das Paket baut auf dem veröffentlichten gemeinsamen Code auf.

## Gefundener und behobener Laufzeitfehler

Die neue echte Reisekette reproduzierte auf der Basis einen leeren `village_simulation.attending`-Bestand, obwohl das gezähmte Tier zuvor wirksam am Gehege versorgt wurde. `SessionFlow.travel_to_planet` deaktivierte den gesamten Quellhost nach der Navigationsvorbereitung, aber **vor** `prepare_far_simulation` und dessen körperlicher Anwesenheitsprüfung. Godot entfernte dabei die `CollisionObject3D`-Formen; die abschließende Bodenprüfung konnte das vorhandene Tier nicht mehr als versorgbar bestätigen.

`SessionFlow` hält die Welt nun während **beider** Vorprüfungen und des gemeinsamen Speicherabschlusses pausiert, mit registrierter Kollision. Erst nach erfolgreicher Sicherung werden der alte Host deaktiviert und freigegeben. Ein Schreibfehler lässt den bisherigen Host samt Kollision und Tier unverändert im Pausenmenü. Besitz-, Produktions- und Saveformate bleiben erhalten; kein Tier wird nachträglich ohne physische Prüfung als anwesend erklärt.

Unveränderte Vertragsversionen: Save 9, Kampagne 3, GameState 4, D2-Tierregister 2 und D2-Kampagnenhülle 1; Dorf-Fernbesitzer, Milchwirtschaft und Tierhaltung behalten ihre bestehenden Versionen.

## Bestehende Besitzer und Prüfung

- `campaign_domestication.gd` und sein D2-Controller behalten Identität, Körperentwurf, Vertrauen, Besitzer und Ortsdaten des Tiers.
- `village_husbandry.gd` und `village_economy.gd` behalten Versorgung, Teilzyklus, Produktionsnachweis, Quittung, Fracht und Bestand.
- `SessionFlow` und `SaveGameService` führen den vorhandenen atomaren Körperwechsel aus.
- `village_simulation.gd` und der tatsächliche `far_scheduler.gd` führen das entfernte Dorf während aktiver Kampagnenzeit weiter.
- `animal_travel_scenario.gd` ist ausschließlich Diagnostik. Es verwendet das Tier und die geladene Milchfracht aus `spherical_gameplay_probe.gd`; keine künstlich angelegten Tier-/Produktionsdaten.

## Zusammenhängende Route

Das geführte Tier wartet innerhalb von 1,2 Metern um die Gehegemitte. Damit bleibt sein vorhandener Bewegungsradius von 0,5 Metern auch nach Kollision oder neuer physischer Darstellung innerhalb der unveränderten D3-Zulassung von 1,8 Metern.

1. Bestehender Neu-Kugelstand, bestätigter Stammesaufstieg, reale Gebäude-/Werkstattarbeit, D1-Tierannäherung und Fütterung, D2-Zähmung, geführter Gang zum Gehege, D3-Zuordnung und echte Versorgungswege.
2. Einen vollständig produzierten Milchbatch physisch abholen. Geladenen Träger an einem echten Kollisionshindernis anhalten; danach warten, bis das gegebenenfalls mitverschobene Tier durch seinen vorhandenen Wartebefehl wieder körperlich am Gehege steht, und wartend speichern.
3. Fehlgeschlagene Abreisespeicherung: derselbe Host und dieselbe Tierinstanz bleiben bestehen; Tierhaltung, Ladung, Autosave-Einstellung und letztes vollständiges Save bleiben erhalten.
4. A → B mit gleichem Weltseed in einem anderen System: alter Host und Tierinstanz verschwinden, Körperidentitäten bleiben getrennt. Genau ein Fernbesitzer und reale D2-Anwesenheit am Tierplatz müssen bestätigt sein. Wartende Milch wird nicht sofort ins Lager gebucht.
5. Während tatsächlichen Spielens auf B mindestens fünf weitere Produktionssekunden mit Futterverbrauch durch den vorhandenen Scheduler nachweisen. Pause hält die Kampagne und die Fernproduktion an.
6. Auf B speichern und einen neuen Engineprozess starten: vollständiger entfernter Körper einschließlich D2, Gehege, begonnener Produktion und Milchfracht bleibt identisch; keine Offlineproduktion und kein fremdes Tier auf B.
7. Rückkehr A: Produktions-/Futter-/Lager-/Quittungsstand vor Wiederaufnahme unverändert; genau ein körperlich dargestelltes eigenes Tier, dieselben Bewohner und derselbe Tierplatz.
8. Bestehende lokale Neustartprüfung weiterführen und die Milch tatsächlich abliefern. Das Kollisionshindernis steht vor dem Träger im Weg. Der bisherige Prüfwürfel umschloss seinen Körper und konnte ihn unter die Bodenfläche drücken; der neue Aufbau bestätigt ausdrücklich erhaltenen Bodenkontakt. Die Prüfbedingung verlangt nun geleerte Trägerfracht und gestiegenen Milchbestand (einschließlich nachweislich verzehrter Milch). `milk_received` allein kennzeichnet die Batchannahme und reicht dafür nicht aus.

Die Route ist Teil des vorhandenen `spherical_gameplay_test` und des bereits vorhandenen nativen `--sphere-gameplay-smoke`-Einstiegs. Keine doppelte lange Testkette wird zusätzlich in die CI eingetragen. Der Zeitrahmen für genau diesen Quellen-/Paketprobe beträgt wegen zusätzlicher Reisen und Neustart 900 Sekunden; die begrenzten Einzelwartezeiten und sonstigen Prüflimits bleiben erhalten.

## Ausführung

```bash
python3 tools/validate_godot.py --godot /pfad/zu/godot --skip-main \
  --tests spherical_gameplay_test --output /tmp/voxelverse-animal-travel
```

Die Diagnose schreibt vor der Reise eine echte Quellkopie `animal_travel_fixture_save.json` und vermerkt den ursprünglichen Slot in `animal_travel_fixture.json`. Für gezieltes Wiederholen muss das isolierte Benutzerprofil einschließlich referenzierter Regionsblobs erhalten werden; die Quellkopie wird dort am ursprünglichen gültigen Slotpfad wiederhergestellt. Die reguläre Slot-Pfadprüfung bleibt bestehen. Der Standardrunner verwendet und entfernt wie bisher temporäre, getrennte Benutzerprofile; der Diagnosecheckpoint ist kein zusätzlicher Spielstandtyp.

## Integration und Grenzen

- Bei gemeinsamer Integration mit PR #53 dessen Vertragsgate und Ergebnisfelder behalten; in `tools/validate_godot.py` nur das spezifische Zeitlimit der erweiterten Kugelkette ergänzen. Die bestehende Test-ID bleibt registriert. Im bereits vorhandenen Szenario `near_far_cargo` kann die Integration anschließend den Nachweis für das echte Tier bei A → B → A ergänzen; die Grenzen für lange Abwesenheiten bleiben offen.
- ARCH-20 verändert die Produktionsverträge; die erweiterte Kette muss nach Übernahme jenes exakten fertigen Commits gemeinsam erneut laufen.
- Die Probe verlangt kein Schiff und transportiert das Tier nicht zum Zielplaneten: Es bleibt als Eigentum am Gehege auf A, arbeitet dort entfernt weiter und wird bei Rückkehr wieder dargestellt.
- Keine Größenabnahme für viele Siedlungen/Regionen, keine lange Abwesenheit über Spieljahre und kein Ziel-PC-/Grafik-/FPS-Nachweis.

## Ergebnis

In Arbeit; Ergebnisse und konkrete Implementierungsfassung werden nach dem tatsächlichen Lauf ergänzt.
