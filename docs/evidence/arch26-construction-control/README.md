# Baustellenverwaltung: Prüfnachweis

Basis `d57b1ef385728728b132518a1ea05683888dcae0` (PR #125).
Geprüfter lokaler Quellcommit `2757f41e326804b8ad6ca8d9ce4d508adfdd4d1c`,
veröffentlicht als `993e9fa60f0291501199cce725b85dd4cab53d6b`.
Identischer vollständiger Tree: `e16b52b0056c11f809f72204484a8281f5320fda`.
Die GitHub-Anbindung vergibt neue Commit-IDs; der Tree wurde exakt verglichen.

## Abschließender Lauf

Godot **4.6.3.stable.official.7d41c59c4**, Linux/headless, isolierte Nutzerdaten.
Sauberer Arbeitsstand; keine Änderung während des Laufs. Befehle und
SHA-256-Quellzuordnung stehen in [results.json](results.json).

```sh
python3 tools/validate_godot.py --godot GODOT_4_6_3 \
  --tests construction_control_test construction_runtime_test \
  village_work_snapshot_test tribal_progression_test \
  --skip-import --skip-main --output AUSGABE_AUSSERHALB_DES_PROJEKTS
```

Alle vier Fachtests und Quell-/Sprach-/Vertragsgate bestanden. Import und
Art-Quellprüfung wurden zuvor im selben Checkout erfolgreich durchgeführt;
spätere Änderungen betreffen GDScript und Dokumentation. Registry: 196 Tests,
18 Verträge; dies ist keine Ausführung aller 196 Tests.

- Neue Modellprüfung: **88 Prüfbedingungen plus 16 in einem frischen Prozess**.
  Alle acht materialführenden Bautypen, bezahlte Altprojekte, Migration 3→4,
  Pause, Lieferungen unterwegs, Abbruch, Lagergrenzen, reservierter Lagertransport,
  Nah/Fern, blockierter Träger, zwei Siedlungen, Beobachtungskopien,
  Bauversuchskennung, Wiederholungsschutz und Zukunftsversionsschutz.
- Neuer Laufzeittest: **41,794 s**. Reguläre Kugelkampagne mit bestätigtem Stamm;
  echte Bewohner tragen Baumaterial zur Baustelle und zurück. UI-Pause,
  Abbruchbestätigung, Schreibfehler/Rollback, Neubau am freigegebenen Ort und
  Fortsetzung nach Live-Save/Load. DE/EN × drei Fenstergrößen × 100/150 % Skalierung.
- Direkte Beobachtungs-/Fortschrittsverbraucher: Snapshot- und Stammesfortschrittstest
  nach den letzten Änderungen erneut erfolgreich.

Im früheren gezielten Lauf `validation-targeted` bestanden zusätzlich
`workplace_instances_test`, `tribal_age_housing_recovery_test`,
`site_transport_test`, `save_participants_test` und
`tribal_economy_progress_test`. Ihre damaligen Quellen sind im Archiv festgehalten;
sie werden nicht als neuer gemeinsamer Lauf aller Fälle am letzten HEAD ausgegeben.

## Erhaltene Erstbefunde

[validation.tar.xz](validation.tar.xz) enthält die vollständigen Resultate,
Rohprotokolle und Quellmanifeste aller Fachläufe sowie die zusätzliche Laufzeitdiagnose.

- Der erste neue Modelltest verwendete versehentlich den nativen Klassennamen
  `Control` als Konstantennamen. Testkonstante umbenannt; kein Spielfehler.
- Der erste Spielablauf deckte eine unnötige vollständige Wegeprüfung nach
  Arbeitsplatzrückbau auf. Nur tatsächliche Unterkunftshindernisse lösen sie aus;
  reine Pause-/Fortsetzen-Metadaten verändern keine Wegegeometrie.
- Zwei Zwischenläufe endeten mit Exitcode 1 und unvollständigem Weltstartprotokoll.
  Aus diesen Läufen wird kein Erfolg abgeleitet. Die spätere Diagnose mit
  Checkpoint-Ausgaben erreichte den vollständigen Ablauf.
- Die Diagnose zeigte einen zu frühen Testklick unmittelbar nach `game_loaded`:
  Der Controller wird erst in späteren Frames wieder aktiv. Der Test wartet jetzt
  auf diese vorhandene Bereitschaft; der Schutz vor Befehlen während des Ladens
  bleibt erhalten. Der finale reguläre Runner besteht denselben Spielablauf.
- Warnungen über absichtlich blockierte Schreibdateien und Zukunftsversionen
  gehören zu den geprüften Fehlerfällen. Echte Fehler der Erstläufe bleiben erhalten.

Keine native Windows-/Grafik-/FPS-Abnahme oder volle Integrationssuite. Die
Layoutmatrix prüft erreichbare Bedienelemente headless, keine gerenderte Optik.
Die Nachweislieferung ergänzt ausschließlich Dokumentation und Prüfartefakte.
