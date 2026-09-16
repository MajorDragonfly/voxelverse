# BP-COMMUNITY-LIBRARY-FAVORITES — Prüfung

## Quellstand

- Basis: `d57b1ef385728728b132518a1ea05683888dcae0` (#125).
- Lokal geprüfter Quellcommit: `b7524472c408775964d1fed35d33e31ccd322331`.
- Veröffentlichter Quellcommit: `1c6b814a7f7f5aec53b93fc5612818ec9ce2b0b7`.
- Exakt gleicher Tree: `4db23ba0b42cfecd3d076a7718106132ecd5e903`.
- Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless,
  isolierte synthetische Nutzerdaten je Prüfschritt.

Der Abschlusslauf begann und endete mit sauberem Arbeitsstand. Die Quelle blieb
während sämtlicher Prüfschritte unverändert. Die GitHub-Anbindung erzeugt andere
Commit-IDs, erhält aber den vollständig verglichenen Quellbaum.

## Abschlusslauf

```sh
python3 tools/validate_godot.py \
  --godot /workspace/scratch/2c2866d70564/godot \
  --tests creature_library_favorites_test creature_design_library_test creature_library_ui_test community_blueprint_package_test localization_test \
  --skip-main --skip-import \
  --output /workspace/scratch/97e7c57ff0f3/favorites-final-check
```

Fünf Fachtests sowie Quell-/Sprachgate und Quellintegrität bestanden:

| Prüfung | Ergebnis | Dauer |
|---|---|---:|
| Neue Favoriten-/Bedienprüfung, einschließlich echtem Neustart | bestanden | 16,31 s |
| Bestehende Bibliothek und Startvorlagen | bestanden | 5,60 s |
| Gemeinsamer Editor-/Startmenü-Picker, Undo/Redo und realer Kugelstart | bestanden | 23,81 s |
| Portabler Bauplanvertrag | bestanden | 8,19 s |
| Lokalisierung | bestanden | 1,77 s |

Die neue Prüfung enthält 91 Bedingungen: Schema-1-Migration, idempotente
Änderungen, Backuperhalt, exakte Revisionen, gleichnamige Designs,
Namensraumkollision, lokaler Import einer Startvorlage, eigene Varianten,
Export/Import ohne Gerätemetadaten, Entfernen/Neuimport, blockierte Schreibpfade,
fremde oder ungültige Daten, Neustart, tatsächliche Mausbedienung, Vorschau-/Namens-
und Kamerastabilität sowie kombinierte Suche/Filter. Zwölf Kombinationen aus
DE/EN, 800×600/1280×720/1920×1080 und Skalierung 1/1,5 prüfen erreichbare Controls.

[Unveränderter Abschlussbericht](results.json) ·
[Alle Rohlogs und vollständige finale Quellmanifeste](validation-logs.tar.gz) ·
[Prüfsummen](sha256.json).

## Ursprüngliche Befunde

Die früheren Berichte und Rohlogs bleiben im Archiv:

- `favorites-initial-check`: Import und Art-/Quellgate bestanden. Ein typstrenger
  Arrayvergleich akzeptierte aus JSON gelesene Versionszahlen nicht; die
  Versionsprüfung verwendet jetzt explizite numerische Typen und Werte. Der neue
  Test verwendete außerdem einen Namen, der Godots native Panel-Klasse verdeckte.
  Die bestehende UI-Prüfung lief nach den Folgefehlern in ihre Zeitgrenze.
  Korrekturen begannen während dieses bereits fehlgeschlagenen Laufs; dessen
  Quellintegrität ist daher ausdrücklich nicht wiederverwendbar.
- `favorites-contract-check`: Bestehende Bibliothek und kompletter UI-/Kugelstart
  bestanden. Ein neuer Migrationsprüffall erzeugte seine Altdatei mit ungerundeten
  Entwurfszahlen statt der tatsächlichen portablen JSON-Repräsentation des alten
  `Library.add`. Die Testvorbereitung entspricht jetzt dem bisherigen Schreiber;
  der Schutz unveränderlicher Revisionen wurde nicht abgeschwächt.
- `favorites-identity-check`: Der neue Ablauf bestand einschließlich der
  zusätzlich abgesicherten Doppelpunkt-Kollision in gültigen Designkennungen.
  Anschließend wurde die maximale Startvorlagenrevision noch an die bestehende
  Paketkonstante gebunden. Diese Änderung ist im Abschlusslauf enthalten.

Der erste Ressourcenimport erfolgte in diesem Checkout. Danach änderten sich
nur Skripte, Tests und Dokumentation; der Abschlusslauf behauptet keinen weiteren
Grafik-/Audioimport, keine Vollsuite und keinen nativen Export.

## Grenzen

Bedienung und Controlrechtecke wurden mit dem tatsächlichen Godot-Picker
headless geprüft. Es gibt keine gerenderte optische Abnahme dieser Lieferung.
Windows-Export, nativer Dateiauswahldialog, Ziel-PC-FPS und gemeinsame Integration
stehen aus. Lokale Favoriten sind kein Online-Community-Katalog.

Der Folgecommit ergänzt ausschließlich diesen Nachweisordner. Zentrale
Statusseiten aktualisiert die Integration.
