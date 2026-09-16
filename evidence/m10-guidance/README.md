# M10-GUIDANCE · abgeschlossene Fachprüfung

- Basis: `d57b1ef385728728b132518a1ea05683888dcae0`.
- Geprüfter lokaler Quellcommit: `eb13ac1f35b9dfc2638839985ce0ea5bd7f836d4`.
- Inhaltlich identischer veröffentlichter Commit: `71ce07226a2b2c7dd7ff60006ea9c7cd9751a08e`.
- Gemeinsamer Quell-Tree: `9dca3b5bcf69d600f2c68fabba9f9c089b5b3f53`.
- Arbeitsstand vor/nach dem Lauf sauber; Runner-Provenienz `stable`, `reusable: true`.
- Godot `4.6.3.stable.official.7d41c59c4`, Linux headless, isolierte Nutzerdaten je Test.
- Der nachfolgende Nachweiscommit ergänzt ausschließlich Dokumentation und Logs.

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests onboarding_test onboarding_guidance_world_test save_participants_test hud_layout_test \
  --skip-main \
  --output /workspace/scratch/176ae31ef22c/guidance-final-01
```

Alle vier Tests, der Import und die Quellenprüfungen bestanden. Die vollständigen
Abschlussmarker sind in den jeweiligen Logs vorhanden; die Weltprüfung bestätigt
zusätzlich den Abschluss ihres frischen Unterprozesses. Keine Script-Fehler.
Die zwei Warnungen über `missing_guidance_parent` sind absichtlich ausgelöste
Speicherfehler; Heimat und Befehl werden dabei zurückgerollt und nicht abgehakt.

| Prüfung | Belegt |
|---|---|
| `onboarding_test` | Schema-1-Migration, Teilfortschritt, Kapitelwahl, beliebige Reihenfolge, Ausschalten, Neustart, Kopie, Wiederherstellung, Legacy- und Zukunftsschutz einschließlich Schema 2.5 |
| `onboarding_guidance_world_test` | Normaler Kugel-Einstieg, echte endliche Nahrung und Süßwasser, volle/ungeeignete Versuche, Heimat-/Befehl-Fehlerspeicherung, erfolgreiche Befehle in Pause, Kopie, bestätigter und abgebrochener Stammeswechsel, frischer Prozess |
| UI-Anteil der Weltprüfung | Alle neun Karten × DE/EN × 800×600/1280×720 × 100/150 % = 72 Zustände; scrollbar bleibende Hilfe, Kapitel-/Aus-/Neustartknöpfe, offener Sprachwechsel, aktuelle Interaktionstaste, Zukunftsdaten ohne Bearbeitung, kein Punkte-/Spielerzustandsgewinn durchs Lesen |
| `save_participants_test` | Gemeinsamer vollständiger Snapshot und Neustart, Registrierung und optionale zukünftige Guide-Daten |
| `hud_layout_test` | Vorhandener HUD, Minimap, Scanner, Spielmeldungen, Menü-Rückkehr und Kugel-Lebenszyklus |

`results.json` und Logs sind unverändert übernommen. Die identischen Start- und
End-Manifeste des Runners liegen platzsparend gemeinsam in
`source-manifest.jsonl.gz`; entpackter SHA-256:
`91bda7152551d5d237b33a69e2f452731748b0292bd1fed6ae8b895670904dab`.
`sha256.json` sichert die kopierten Belege. Absolute Runner-Pfade dokumentieren
die tatsächliche Testumgebung; deren Inhalt ist hier beigefügt.

Die Prüfung ist eine abgegrenzte Quell-/Headless-Abnahme. Kein nativer Export,
keine Gesamt-/FPS-Freigabe und keine gerenderte Windows-Sichtabnahme. Beim
Zusammenführen muss die Integration den neuen Merge-Tree prüfen.
