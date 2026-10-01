# INT30-19-TRIBAL-GUIDANCE

Die neue eingebettete Hilfekarte erklärt den nächsten echten Stammesauftrag und belegte Hindernisse. `core/onboarding_progress.gd` und der bestehende Ereignisbeobachter bleiben die einzigen Fortschrittsquellen. Die Karte und der Kontextblock in der Hilfeseite lesen den bestehenden Zustand; ihr Erklären-Knopf zeigt ausschließlich Text.

## Grundlage und Dateigrenze

Feste INT30-Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree `5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Branch `agent/int30-19-tribal-guidance`; PR-Ziel `agent/integration-pt19-20260930`. Die Zuordnung für Chat 19 wurde in [#137, Kommentar 5918892397](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5918892397) bestätigt; die Anschlüsse wurden in [Kommentar 5919087172](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5919087172) konkretisiert.

Nur neue eigene Hilfsmodule, Tests, UIDs, Render-Treiber und dieser Belegordner werden geliefert. Bestehende Stammes-, Menü-, Onboarding-, Speicher-, Katalog-, Registry-, CI- und zentrale Statusdateien bleiben im Fachbranch unverändert. Die vorgeschlagenen Besitzeränderungen sind separate Patches; sie sind ausschließlich im abgetrennten Prüfcheckout angewandt.

| Modul | Verantwortung |
| --- | --- |
| `ui/tutorial/tribal_context_source.gd` | Kopiert den aktuellen Controllerzustand und merkt ausschließlich abgelehnte Auftragsdiagnosen. Schwache Referenz; Ab-/Neubinden trennt alte Beobachter. Geänderte Auswahl, Vorräte, Werkzeug, Projekt oder Status verwerfen überholte Diagnosen. |
| `ui/tutorial/tribal_context_guidance.gd` | Reine Entscheidung aus vorhandener Stammesübung, Auswahl, Vorrat, Fracht, Bauzustand und Live-Vorschau. Keine Migration, Wegsuche, Aufträge oder Fortschrittsbuchung. |
| `ui/tutorial/tribal_guidance_card.gd` | Karte im vorhandenen HUD-Scrollbereich; bestehender Stil und bestehende Tastaturhinweise. Der Knopf klappt die Erklärung auf und zu. |

## Erklärte Handlungen

- Auswahl: keine oder entfernte Bewohner, Einzel- und Gruppenauswahl; eine bereits laufende Lieferung braucht keine erneute Auswahl.
- Arbeitsauftrag: vorhandene Quellen und Voraussetzungen; laufende Sammlung ist noch keine Lieferung. Leere zugewiesene Quelle wird von insgesamt leeren Quellen unterschieden.
- Lieferung: tatsächlich getragene Lagerfracht und tatsächliche Ankunft. Bau- und Tierpflegefracht werden nicht als Lagerlieferung dargestellt.
- Versorgung: tatsächlicher Hunger/Durst und eingelagerte essbare Ware/Wasser. Ein schon versorgter Bewohner erzeugt keine künstliche Pflegehandlung.
- Bau: echte Rezeptkosten und Fehlbetrag, ausreichend unterwegs befindliche Ware, Werkzeugauftrag, Boden-/Wegevorschau, reserviertes/getragenes/angekommenes Baumaterial, fehlende Arbeiter, Pause, Rücklieferung und laufende Bauarbeit.

Ein `blocked`-Zustand belegt eine Blockierung, aber kein bestimmtes Hindernis. Der Helfer behauptet deshalb keinen Baum, Felsen oder anderen unbeobachteten Grund. Abgelehnte Aufträge und Live-Bauvorschauen zeigen den tatsächlich gemeldeten, über die bestehende Stammesdarstellung übersetzten Grund. Zukünftige Schemas, übersprungene Einführung und inaktive Hosts bleiben still. Pausierte Hilfeseiten dürfen den bekannten aktiven Dorfzustand lesen, ohne den Host zu aktivieren.

## Besitzeranschlüsse

| Besitzer | Anhang | Umfang |
| --- | --- | --- |
| Chat 6 | [chat6-tribe-panel.patch](patches/chat6-tribe-panel.patch) | Drei Zeilen: Karte erstellen, Controller zuweisen, in vorhandenen Scrollinhalt einfügen. Kein Controllerpatch. |
| Chat 9 | [chat9-help-page.patch](patches/chat9-help-page.patch) | Lesender Titel/Grund/nächster Schritt in bestehender Stammeshilfeseite; vorhandene Kapitelknöpfe unverändert. |
| Chat 10 | Kein Speicherpatch erforderlich | Ausschließlich vorhandene `SaveGameService.guidance` lesen. Kein neues Feld, SaveParticipant, Fortschrittssignal oder Reward-Aufruf. |
| Chat 1 | [chat1-test-registry.patch](patches/chat1-test-registry.patch), [chat1-world-test-budget.patch](patches/chat1-world-test-budget.patch) | Drei Tests genau einmal unter `frontend_locale`; neuer echter Weltverbraucher im vorhandenen 420-s-Langtestbudget. |
| Chat 1 / Lokalisierungsbesitzer | [localization-append.json](patches/localization-append.json) | 67 zusätzliche DE/EN-Nachrichten in den gemeinsamen Katalog übernehmen und die bestehenden PO-Dateien mit `tools/localization/catalog.py` erzeugen. Keine parallele Produktionsübersetzung. |

Die `.patch`-Dateien haben bewusst keinen Kontext und werden auf der festen Fachbasis mit `git apply --unidiff-zero` angewandt. Vorher `git apply --check --unidiff-zero PFAD` ausführen; bei veränderten Besitzerdateien dieselben engen Ergänzungen an der entsprechenden Stelle übernehmen. [registry-append.json](patches/registry-append.json) beschreibt dieselbe Registrierung maschinenlesbar; nicht zusätzlich nochmals registrieren.

`tests/int30_tribal_guidance_support.gd` installiert den Sprachappend ausschließlich für isolierte Testfixtures. Im Produkt ist die zentrale Katalogübernahme erforderlich.

## Prüfungen und Reproduktion

Godot `4.6.3.stable.official.7d41c59c4`; Linux, isolierte Nutzerdaten. Der bestehende Validierungsrunner und `SourceRun` identifizieren die tatsächlichen Quellen, unveränderte Arbeitsstände sowie Log-/Bilddigests. Outputs liegen während der Prüfung außerhalb des Projekts.

```sh
python3 tools/validate_godot.py --godot /PFAD/godot \
  --tests int30_tribal_guidance_test int30_tribal_guidance_ui_test \
  tribal_guidance_test int30_tribal_guidance_world_test \
  --skip-import --skip-main --output /PFAD/NEUER-AUSGABEORDNER

python3 tools/review_int30_tribal_guidance.py --godot /PFAD/godot \
  --xvfb /PFAD/Xvfb --mode ui --output /PFAD/NEUER-UI-ORDNER

python3 tools/review_int30_tribal_guidance.py --godot /PFAD/godot \
  --xvfb /PFAD/Xvfb --mode world --output /PFAD/NEUER-WELT-ORDNER
```

`--skip-import` setzt einen bereits erfolgreich importierten identischen lokalen Ressourcenstand voraus. `--xvfb` ist optional bei vorhandenem Display; der Treiber startet Xvfb und Godot im selben Netzwerkraum. Native Belege verwenden Compatibility / Mesa 25.2.8 / llvmpipe LLVM 20.1.2 / Dummy-Audio, keine Ziel-PC- oder FPS-Abnahme.

Der UI-Verbraucher prüft echte Mausaktionen, DE/EN, 800×600/1280×720/1920×1080 und 100/125/150 %; er rendert acht Ablaufzustände plus sechs Layoutansichten. Der Weltverbraucher verwendet den regulären Kugel-Spieltesteinstieg, explizite Stammesbestätigung, vorhandenen Controller, reale Wege/Aufträge/Ankünfte/Verbrauch, normale Bauvorschau und Baustellenpause sowie Save/Load. Für den Bauabschnitt wird eine offengelegte, begrenzte Fixturemenge aus endlichen Vorkommen ins Lager umgebucht; die Hilfe selbst erzeugt keine Ware. Eine vorübergehende Blockierung verwendet die realen Navigationspunkte mit getrennten Kanten, keine gefälschten Arbeitsereignisse.

Die Szenenressourcen werden vor der Session vorbereitet. Der Tutorialverbraucher verwendet SessionFlows vorhandenen 180-s-Geländewatchdog und separat die vorhandene Bestätigungsvorbereitung. Native Arbeitsphasen behalten ihre tatsächlichen Physikzeitgrenzen und einen begrenzten 180-s-Wandzeitwatchdog. Im nativen Weltlauf wird die echte 3D-Welt an Aufnahmegrenzen rasterisiert; Physik, Szenenknoten und GUI laufen dazwischen weiter. Das isoliert den Funktionsnachweis von der Software-Rastergeschwindigkeit. Es ist kein Kaltstart- oder Performancenachweis.

Die konkreten Quellstände und Ergebnisse stehen in [verification.json](verification.json). Veröffentlichter Codecommit `0b8150aaf4214b90aee13c235654b6436319d564` und lokaler Codecommit `f4714548c8bc8e9fd05d2908ed90d8ec0ddcfd00` haben exakt Tree `c849fa6895da261e30896b5c6b5234b0d7538225`. Die separate Prüfkomposition hat Commit `0706be0c4b60e99e91688461211e64f2ae1e200a`, Tree `68ac63d04c5ed1d545f2a9ba0acc9d3a16ea85b5`, Source-SHA256 `bd913f6127daa05f90c9128ba666fee16bd292de52d95ccf979407ddfcac9017`. Alle 21 Fachdateien sind bytegleich; [Dateidigests](checked-code-files.json). [Die sieben Besitzerdateien](checked-owner-files.json) sind als komprimierter exakter Kompositionspatch beigefügt.

| Finaler Nachweis | Ergebnis |
| --- | --- |
| [Fach-/UI-/Speicher-/Weltprüfung](runs/headless-complete/results.json) | Alle drei neuen Tests und `tribal_guidance_test` bestanden. 157 Fachkontrollen; 78 isolierte UI-Kontrollen; echte zwölf Weltzustände, 18 Layoutfälle, pausierte Hilfe DE/EN und Save/Load. |
| [Direkte Menü-/Onboarding-Verbraucher](runs/direct-consumers-complete/results.json) | `onboarding_test` und `frontend_test` auf derselben finalen Prüfquelle bestanden; einschließlich Menüaktionen, Hilfe/Skip/Restart, fehlgeschlagener Speicherungen und neuer Sitzung. |
| [Native UI](runs/ui-complete/results.json) | 92 Kontrollen, 14 Original-PNGs, unveränderte Quelle. |
| [Native Kugelwelt](runs/world-complete/results.json) | 20 Original-PNGs: zwölf tatsächliche Zustände, sechs Layoutansichten, zwei pausierte Hilfeseiten; unveränderte Quelle. |

Logs und Quellmanifeste liegen in den jeweiligen Ordnern gzip-komprimiert, Bild-/Logdigests in den Originalberichten. Repräsentative Aufnahmen von Materialmangel, tatsächlicher Blockierung, erneut geladener Baustellenpause, kleiner englischer Ansicht und pausierter englischer Hilfeseite wurden zusätzlich visuell geprüft.

- [Blockierter realer Weg](runs/world-complete/04-blocked-route-de.png)
- [Tatsächlicher Materialfehlbetrag](runs/world-complete/08-missing-materials-de.png)
- [Hilfe nach erneutem Laden](runs/world-complete/12-resumed-help-de.png)
- [Englisch, 800×600, 150 %](runs/world-complete/layout-en-800-150.png)
- [Pausierte Hilfeseite mit aktuellem Grund](runs/world-complete/help-context-en.png)

Frühere fehlgeschlagene Berichte bleiben ausdrücklich `passed=false`. Sie belegen die zunächst zu kurze Startvorbereitung, eine ungeeignete Pflegeauswahl, Software-Raster-/Physikzeitunterschiede, den eingefrorenen Reload-Prüfaufbau sowie den behobenen JSON-Schemalesefehler. Kein Fehlerbericht wurde nachträglich zu Erfolg umetikettiert. Die neue Leserprüfung akzeptiert ganzzahlige unterstützte JSON-Versionen, verwirft aber weiterhin gebrochene und zukünftige Versionen.

## Integration und Abnahme

Der Fachbranch benötigt die Besitzeranschlüsse und zentrale Registrierung/Katalogübernahme. Sein unveränderter Registry-Plan meldet die drei neuen Tests ausdrücklich als unregistriert; der gepatchte Prüfstand berücksichtigt alle drei. Die konservative gemeinsame Änderungsplanung wählt FULL und wird bei Chat 1 auf dem neuen Integrationstree geprüft.

Vollsuite, gemeinsame Produktions-/Reisekette, die vier Pflichtgates, native Exporte und Windows-/Ziel-PC-Abnahme gehören zur Integration. Der PR bleibt bis zu diesen Anschlüssen im Entwurf; keine main-/Auto-Merge-Freigabe aus Einzelbelegen.
