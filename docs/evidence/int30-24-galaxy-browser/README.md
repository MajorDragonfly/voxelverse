# INT30-24 – separater Galaxiekatalogbrowser

Feste Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`.
Branch: `agent/int30-24-galaxy-browser`; Ziel: `agent/integration-pt19-20260930`.

Der Browser verwendet weiterhin denselben `GalaxyCatalog` und die kanonischen
`GalaxyAddress`-Kennungen. Vier Systeme pro Seite, lokale Namens-/Kennungsteilsuche
über höchstens acht Sektoreinträge sowie direkter Sprung über vollständige
Sektor-, System- und Körperkennungen. Fehlende Slots, fremde Galaxien, ungültige
und leere Sektoren ändern keine Reise-/Erkundungsdaten. Ein Seitenwechsel erzeugt
nur das ausgewählte System, keine gesamte Vorschauseite.

Die zusätzliche Körperauswahl kann auch Sterne und Gasriesen untersuchen. Die
bestehende Reisezielauswahl behält deaktivierte nicht begehbare Einträge und
unveränderte `visit_requested(system_id, body_id)`-Signale. Körperdetails zeigen
Radius/Durchmesser in km, Abstände in km beziehungsweise AU, den tatsächlichen
Bahnbezug (Mond → Planet, Doppelstern → Schwerpunkt), Gravitation und Perioden.
Systementfernungen verwenden `GalaxyAddress.relative_ly`, keinen globalen
Physikvektor. Eine lesende Besuchsquelle kann gespeicherte Rückkehrpunkte anzeigen;
fehlende oder nicht unterstützte Daten werden ausdrücklich als nicht verfügbar
angezeigt. Journalnamen, Notizen und persönliche Markierungen behalten ihren
bisherigen Speichervertrag; sie werden nicht zu Erkundungsfreigaben umgedeutet.

Eine gesamte scrollbare Ansicht ersetzt abgeschnittene Detail-/Notizfelder;
800×600 stapelt die Spalten. Die vorhandene UI-Skalierung wird auch bei 150 %
berücksichtigt. Sektorachse und Eingabe bleiben zusammen. Wiederholtes Enter im
Suchfeld funktioniert, ohne zwischen Suchen erneut in den Bearbeitungsmodus zu
wechseln.

## Gemeinsame Anschlüsse für Chat 1

Die folgenden Besitzerdateien sind im Fachbranch **nicht geändert**:

- `registry.patch`: `int30_galaxy_browser_test` genau einmal unter `campaign` registrieren.
- `lab-visit-reader.patch`: den optionalen Port nur mit einem bereits vorhandenen,
  erfolgreich geöffneten `visits.read` verbinden. Der Browser öffnet oder schreibt
  keinen Besuchsspeicher. Der Null-Guard erhält den ersten Laborstart ohne Katalogbesuch.
- `visit-click-fixture.patch`: bestehende Reiseprüfung scrollt vor dem realen Klick
  zum Ziel und verwendet die tatsächliche Canvas-Transformation. Sämtliche
  Körper-/Bewegungs-/Save-/Neustartassertionen bleiben bestehen.
- `translations.json`: 36 neue DE/EN-Nachrichten an `localization/catalog.json`
  anhängen, danach `python3 tools/localization/catalog.py` ausführen. Bis zur
  Integration verwenden neue Texte ihren deutschen Fallback im vorhandenen
  `UiText`-/`TranslationServer`-Weg. Bestehende deutsche Labor-/Journaltexte sind
  keine vollständige neue DE/EN-Abnahme dieses Pakets.

Die neue Registrierung ist bewusst ein Anschluss-Patch: Der unveränderte
zentrale Source-Checker meldet im rohen Fachbranch den noch unregistrierten Test.
Der Fach-PR bleibt deshalb bis zur Übernahme dieser Anschlüsse ein Entwurf.
Es gibt keine zweite Testregistry oder Katalog-/Kampagnenspeicherimplementation.

## Prüfumfang und Reproduktion

Die Fachprüfung verwendet isolierte Nutzerdaten, den echten Katalog und echte
Enter-/Mausereignisse. Sie deckt Einzel-/Doppelsterne, Gesteinsplaneten, Monde und
Gasriesen, ungültige/fremde/fehlende IDs, Sektorachsen bis ±1.000.000.000, Nahtpräzision,
80 Sektorwechsel, Cacheverdrängung, Seitenbudgets, fehlende/future Besuchsdaten,
blockierte Aktionen während Reise, vorhandene Notizspeicherung und 800×600 bei
100/150 % ab. Die kontrollierte Besuchsprovider-Fixture ist eine Leseschnittstellen-
Prüfung; die bestehende Reiseprüfung testet zusätzlich echte Oberflächen,
Rückkehrpunkte und einen frischen Prozess.

Für die gemeinsamen Anschlüsse wurde ein getrenntes Prüfcheckout von
`6b6fdccb521ae93657fc80e2cdc20c484aa40615` erstellt. Dort werden ausschließlich die
beigefügten Patches und die generierten Übersetzungen ergänzt. Der Fachbranch
behält die Dateigrenzen. Ergebnisse/Quellfingerprints stehen bei den Prüfbelegen;
ein so geprüfter Anschlussstand ist kein bereits integrierter PR-Tree.

```bash
python3 tools/validate_godot.py --changed-since 2b1ac023db4074c2ce6b7db8fbab09ab929a8435 --plan --summary
python3 tools/validate_godot.py --godot GODOT_4_6_3 --tests galaxy_catalog_test galaxy_visits_test int30_galaxy_browser_test --skip-main --output OUTSIDE_PROJECT
python3 docs/evidence/int30-24-galaxy-browser/review.py --godot GODOT_4_6_3 --output OUTSIDE_PROJECT
```

Der konservative Änderungsplan verlangt nach gemeinsamen Sprach-/Registry-
Anschlüssen die volle Integration (248 Tests plus Main-/Runtimechecks). Diese
gehört zu Chat 1; die hier gezielten Verbraucherprüfungen ersetzen sie nicht.

## Gerenderte Ansichten

[720p Navigation](render/galaxy-1280x720-navigation.png),
[Mond und tatsächlicher Elternkörper](render/galaxy-1280x720-moon.png),
[Einzelstern](render/galaxy-1280x720-single.png),
[Doppelsternkomponente](render/galaxy-1280x720-star.png),
[Gasriese](render/galaxy-1280x720-gas_giant.png),
[große leere Adresse](render/galaxy-1280x720-empty.png),
[Fehler direkt unter der Suche](render/galaxy-1280x720-invalid-id.png),
[800×600 Navigation](render/galaxy-800x600-navigation.png),
[800×600 Details](render/galaxy-800x600-body.png),
[800×600 bei 150 %](render/galaxy-800x600-scale150-navigation.png).

[Unveränderte 720p-Fachbasis](baseline/galaxy-1280x720-baseline.png) und
[unveränderte 800×600-Fachbasis](baseline/galaxy-800x600-baseline.png) wurden
mit derselben Seed-Kennung, Anfangsauswahl und Engine tatsächlich gerendert;
kein nachgebautes Vergleichsbild. Die neue Ansicht erhält lesbare physische
Schriftgrößen, weshalb ihre Fensteransichten mehr scrollen als die früher stark
verkleinerte Vollansicht.

Die UI-Aufnahmen laufen mit Godot `4.6.3.stable.official.7d41c59c4`,
Linux, Compatibility, Mesa llvmpipe und isoliertem Xvfb. Zwölf neue und zwei
Baseline-PNGs; SHA256 und Befehle in den jeweiligen `results.json`.
Dies sind UI-Nachweise, keine Forward+- oder Ziel-PC-Leistungsabnahme.
Reise, Freischaltungen, Oberflächenkarte und Kampagnenspeicherung gehören
weiterhin zu ihren vorhandenen Besitzern. Kein main-Merge und kein Auto-Merge.

## Tatsächliche Ergebnisse und erhaltene Diagnose

- Import und Quellen-/Übersetzungsverträge im Anschluss-Prüfcheckout bestanden.
- Bestehender `galaxy_catalog_test` bestanden, inklusive Determinismus,
  Journalfehlern/Revisionen und frischem Prozess.
- Fachprüfung mit 206 Kontrollen bestanden (6,318 s), einschließlich der finalen
  Suchfeedback-Regression. Ergebnis dieses endgültigen Kopfs steht unter
  `validation/final-search/`.
- Bestehender `galaxy_visits_test` mit korrigiertem Anschluss und echter
  Scroll-/Canvas-Klickfixture bestanden: 61,239 s, 149 Kontakte aus 150 Frames,
  34,857 m Bewegung, echter Rückbesuch und Neustart Exit 0. Alle ursprünglichen
  Assertions erhalten; gemeinsames 120-s-Budget unverändert.

Die ersten Diagnosen sind erhalten: Der erste Anschluss ohne Null-Guard brach
beim Laborstart ab. Der danach korrigierte Lauf erreichte alle Reise-/Neustart-
Assertions (`GALAXY_VISITS_PASSED true`), wurde beim Beenden jedoch vom 120-s-
Runner beendet; er ist ausdrücklich **kein** bestandener Nachweis. Die gezielte
Wiederholung mit der endgültigen Feedbackposition bestand vollständig. Die
unterschiedlichen lokalen Zeiten begründen keine Ziel-PC-Performancemessung.
Ein zusätzliches Ressourcenimport-Experiment im Fachcheckout erreichte während
Autoload-Erstellung das bestehende 180-s-Budget; der erfolgreiche Ressourcenimport
im separaten Prüfcheckout bleibt der verwendete Importnachweis. Keine
Timeout-/Assertionänderung und kein unterdrückter Fehler.
