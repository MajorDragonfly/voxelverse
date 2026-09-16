# ARCH-27-SITE-TRANSPORT – Fachnachweise

Godot **4.6.3.stable.official.7d41c59c4**, Linux/headless. Der vorhandene Runner
isoliert Benutzerdaten; sämtliche Speicherstände und Tier-/Ortsnamen sind
synthetische Prüfdaten. Keine echten Nutzersaves werden verwendet.

## Ergebnis und Quellstand

- **12 gezielte Godot-Tests plus Quellenprüfung bestanden** am sauberen lokalen
  `bdbef8fe36e1addd8a71de0138045bc3d3817dfa`, Tree
  `67b6e8da32898ee5fa1d8a5245fe83db1ddb5089`.
  [Maschinenbericht](final/results.json).
- Zwei reine Prüferweiterungen auf sauberem lokalem
  `f901d5f1f0fb3a8f0cf42844d34b799357d99ceb`, Tree
  `7202da0df1993e5f1dd969d587de476d8a4fffe4`:
  aktive Fracht im echten `SaveGameService.prepare_body_target()` und eine gültige
  Berufskennung bei konkurrierender Zuweisung. **Beide Transporttests erneut
  bestanden**, ohne Änderung des Spielcodes. Andere Fachnachweise wiederverwendet.
  [Nachlauf](final-acceptance/results.json).
- Die Transportprüfung enthält jetzt **127 Prüfpunkte und einen separaten
  Godot-Neustart**: sieben Ressourcen, Reservierungen beider Lager, echte
  SaveGameService-Snapshots, Schreibfehler, Pause, fehlendes/geändertes Wegenetz,
  Rückkehr mit Fracht, Abbruch, Ankunft, Wiedereintritt und Zukunftsversionsschutz.
- Der Laufzeittest gründet zwei Orte in der echten Kugelkampagne, lässt einen
  Bewohner Holz sammeln und über reale Physikwege liefern, betätigt die neue
  Versandbedienung und prüft eine zweite Lieferung nach Ortswechsel. Enthalten:
  Rollback bei echtem Savefehler, Pause, eindeutige Trägeridentität, konkurrierende
  Aufträge sowie DE/EN-Texte. Letzter Lauf etwa 99 Sekunden.
- Bestehende direkte Verbraucher: Regionaltransport, Siedlungskollektion, nativer
  Zweitortsave, Fernsimulation, Dorfwirtschaft, Tierhaltung, Eierproduktion,
  Speicherteilnehmer, Planetenreise und Dorfübersetzung.

Der Import und die Art-Quellenprüfung sind in [initial](initial/) dokumentiert.
Die Abschlussläufe verwenden denselben erfolgreich importierten Ressourcenstand
mit `--skip-import`; unveränderte Assets wurden nicht erneut importiert. Die
Spielskripte werden von jedem tatsächlichen Godot-Test neu geladen.

## Reproduktion

```sh
python3 tools/validate_godot.py --godot /path/to/Godot_v4.6.3-stable_linux.x86_64 \
  --tests site_transport_test site_transport_runtime_test regional_transport_test \
  settlement_collection_test settlement_save_test far_simulation_test \
  tribal_age_economy_contract_test tribal_age_husbandry_contract_test \
  egg_production_contract_test save_participants_test body_travel_test \
  tribe_localization_test --skip-main --output /tmp/arch27-validation
```

Beim dokumentierten Abschluss war der Ressourcenimport bereits erfolgt, deshalb
kam zusätzlich `--skip-import` zum Einsatz. Beim späteren Nachlauf blieb die
Testauswahl auf `site_transport_test site_transport_runtime_test` beschränkt.
Vollständige Befehle und Engine-Ausgaben stehen in den Rohprotokollen.

## Korrigierte Anfangsbefunde

Die erste neue Modellprüfung setzte ihre Uhr nach einer vorherigen Lieferung
zurück und blieb in ihrer nicht begrenzten Prüfschleife stehen. Dieser Lauf wurde
abgebrochen; die Prüfdaten-Uhr wurde korrigiert und die Schleife begrenzt. Danach
fielen Nahrung/Wasser in der zusätzlichen Tierfutterbilanz auf: Diese musste die
neuen Ein-/Ausfuhren ebenfalls berücksichtigen und reservierten Platz von Ware
unterscheiden. Die unveränderten Originalprotokolle stehen unter `initial/`.

Die ursprünglich ergänzte Berufsprüfung verwendete eine unbekannte Berufskennung;
der abschließende Nachlauf verwendet den vorhandenen Beruf `forester`.
Warnungen zu fehlgeschlagenem Schreiben und unbekannten Zukunftsversionen sind
absichtlich ausgelöste Fehlerfälle. Keine Fehler werden durch den Runner ignoriert.

## Veröffentlichung und Grenzen

[Manifest](manifest.json) enthält Dateihashes und die exakte Zuordnung lokaler zu
veröffentlichten Commits. Die GitHub-Anbindung vergibt andere Commit-IDs; beide
Quelltrees wurden beim Übertragen exakt verglichen. Originalberichte behalten ihre
lokalen Referenzen. Der nachfolgende Evidenzcommit ergänzt ausschließlich Nachweise.

Kein gemeinsamer Integrations-/Windows-Export, kein grafischer Screenshot-/Layout-
oder Ziel-PC-/FPS-Nachweis. Echte Physiktests im Headless-Modus belegen den
Spielablauf, keine visuelle Abnahme oder Bildrate. Die zentrale CI und endgültige
Zusammenführung gehören zur Integration.
