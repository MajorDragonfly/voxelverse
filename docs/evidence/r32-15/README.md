# R32-15 · Esc/Grafik · #180

Feste Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree `f2bda4f815df1c73b9d740ca5282917523faf618`.

## Belegte Fehler und enge Korrekturen

- Controls: Tastaturfokus auf Reset lag nach dem Containerlayout außerhalb des Scrollbereichs. `controls_settings.gd` folgt ausschließlich diesem Reset-Fokus nach zwei Layoutframes. Ein zunächst allgemeiner Fokusanschluss erzeugte im nativen CI-Verbraucher eine echte Mouse-Rebinding-Regression und wurde wieder eng begrenzt; der negative Originallauf bleibt erhalten.
- Zentraler DisplaySettings-Host: 125 % wurde beim unveränderten Grafik-Apply auf 120 % quantisiert. 150 % wurde beim Laden auf 135 % begrenzt und beim nächsten Apply auf 130 % verändert. Ownerpatch ergänzt beide exakten Optionen und die Ladegrenze 1.5.
- Tatsächliche 150 %: Einstellungsfenster 796 logische Pixel hoch bei 720 verfügbaren in 720p/1080p (DE/EN). Ownerpatch passt ausschließlich die Tab-Scrollhöhe an den vorhandenen Viewport/Chrome an; Apply/Zurück bleiben außerhalb dieses Scrollbereichs.

Der Fachbranch verändert `core/display_settings.gd` und die gemeinsame Testregistry nicht. R32-01 wendet `display-scale-owner.patch` mit `git apply --unidiff-zero` und `registry-owner.patch` genau einmal an. `workflow-owner.patch` ist ein optionaler additiver Diagnoseanschluss für R32-01; die Workflowdatei selbst liegt ausschließlich im getrennten Diagnosebranch. Audioseite bleibt R32-16, Stammeskamera R32-04.

## Prüfung und Grenzen

Die negativen Originale unter `reproductions/` stammen aus zunächst schmutzigen Reproständen, keine wiederverwendbare saubere SourceRun-Abnahme. `baseline-settings-run.log`: 18 Kontrollen, sechs negative Assertions. `leaf-settings-run.log`: derselbe kurze Fall nach Controlsfix, nur die fünf erwarteten Host-Skalierungsassertions negativ. `owner-settings-layout-run.log`: freigeschaltete 150 % vor Layoutfix, 54 Kontrollen, vier Overflows. Exakte ursprüngliche 18-Check-Testquelle: Commit `a45765bc118db491b73f653bd73b2b7fba184931`, Test `tests/r32_15_settings_navigation_test.gd`; Controls vor dem Fix wie Basis. Der Basisimport ist positiv. `native-same-call.log` belegt nur die verfügbare Linux-X11/GL-Umgebung, keine Gameplayabnahme.

Der Folgelauf der bestehenden nativen Linux-Frontend-CI ist vollständig positiv: [Run 36973559054](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973559054), Job 110732453757, echter Mergecommit `bb0428a5f6e3a5c01cf688405999c9328e25a5f8` (Fachkopf `15f9d0e2ec0b19830e1f7c9ca8e37e50f3a5c7c2` auf Integrationskopf `a7ac6b79e9a36a87a42eabab6c454590575cd2a1`). Titel-/Maus-Rebinding-/Save-Verbraucher, HUD, beide Esc-Phasen und vorhandener kombinierter Menü-Audio-Buch-Verbraucher grün. Originalarchiv 11212877532, SHA256 `b04b71a1042f0ed70346622883cc748cb2a5d39fdfdd14e6f144fdb1395dbe22`, 37 811 730 Bytes; Gesamtdownload überschreitet die lokale 32-MiB-Transfergrenze, daher dessen Bilder nicht als lokal sichtgeprüft behauptet. Die eigene engere Bildprobe wird separat übergeben. Der ursprüngliche CI-Frontendlauf 36972372455 / Job 110728855448 am echten Mergecommit `ed2a58ee976f13a1682bb81791c565d996a6fa71` scheiterte an acht Folgeassertions der verzögerten allgemeinen Focus-Reveal-Korrektur. Der neue fokussierte Test verwendet `_exercise_controls()` des unveränderten originalen `frontend_probe.gd` als direkten Verbraucher. CI-Plan 36972372472 / Job 110728855632 scheiterte ausschließlich vor Testbeginn an beiden noch zentral anzuhängenden Testregistrierungen, kein erfolgreiches Vollgate. Eigenständiger konservativer Prüfwähler auf der Ownerpatch-QA-Kopie verlangt FULL 269/269; der Plan ist keine ausgeführte Suite. Vollsuite, gemeinsame Produktions-/Reisekette, vier Pflichtgates und native Release-Exporte bleiben R32-01. Keine eigene Vollsuite gestartet.

Die eigenen nativen Windows-Editorbelege sind positiv und unten getrennt beschrieben. Release-Export-/Ziel-PC-Sichtabnahme ist nicht vorhanden; #180 bleibt offen. Software-GL auf llvmpipe erlaubt keine Ziel-PC-Leistungsaussage. Die öffentliche Kampagnenprobe nutzt den bestehenden wegwerfbaren TribalPlaytest-Einstieg und dessen normale bestätigte Phasenfreigabe; die gesamte vorherige Survivalentwicklung wird damit nicht nachgespielt. Isolierte 2D-Settingsbilder werden separat gekennzeichnet.

## Saubere eigene Windows-Prüfung

[Diagnoselauf 36975118419](https://github.com/MajorDragonfly/voxelverse/actions/runs/36975118419), Windows-Job `110737151102`, Quellcommit `ade9169d46c5f936635072051c57082c486e442b`, Tree `f64073b212b482c705cd656bcc030ea18694b641`. Dieser isolierte QA-Tree enthält den festen Basisstand, die Fachquellen und die beiden angewandten Besitzerpatches sowie die eigene optionale CI-Datei. Lokaler QA-Commit `81c4a98259b33e9100a1be443f8610b422ae9cf6` hat exakt denselben Tree. Alle vier SourceRun-Berichte sind sauber, vollständig, unverändert und `reusable=true`; ihr gemeinsames originales Start-/Endmanifest liegt einmal unter `windows/source-files-start.jsonl`.

| Eigener Fall | Kontrollen | Ergebnis |
| --- | ---: | --- |
| 2D-Settings, Headless, volle 18er-Matrix | 58 | bestanden |
| Öffentliche Kampagne, Headless, beide Phasen / 36 Fälle | 676 | bestanden |
| Native Windows-Settings, volle 18er-Matrix | 130 | bestanden, 36 Bilder |
| Native Windows-Kampagne, beide Phasen / 12 Fälle | 344 | bestanden, 50 Bilder |

Godot `4.6.3.stable.official.7d41c59c4`; Windows Server 2025 `10.0.26100`; tatsächlicher Windows-Displayserver, OpenGL-ES-3.0-Compatibility über ANGLE/D3D11 auf Microsoft Basic Render Driver. Das ist ein nativer Windows-Editorbeleg auf einem Software-Runner, keine Windows-11-Ziel-PC-, Release- oder FPS-Abnahme. Alle 86 Originalbilder wurden gegen die im jeweiligen Bericht gespeicherten PNG-Hashes und Abmessungen geprüft. Neun Originalbilder wurden visuell geprüft und bytegleich eingecheckt; die vollständige Sammlung samt Logs/Manifesten liegt im [Originalarchiv 11213458729](https://github.com/MajorDragonfly/voxelverse/actions/runs/36975118419/artifacts/11213458729), 21 035 359 Bytes, SHA256 `04e5ebc8ca9c6a9e24b3b962604e535b4796943268ba6f55453a88cfe069aa9e`.

Der native Weg betätigt Pause und Fortsetzen, schließt erst Popup/Binding-Aufnahme und danach Einstellungen/Pause, prüft Außenklick/W/Simulationszeit/Position/Stammesauswahl hinter den Modalen, Hilfe-/Erste-Schritte-Rückwege, taktische Pause und F8, Grafik-Apply `.93`, unveränderte Übernahme von 125/150 %, Verwerfen `1.04`, erneutes Öffnen, Titelrückkehr und Fortsetzen. Je Phase liest ein echter frischer Prozess dieselben isolierten gespeicherten Grafik-/Skalierungs-/Sprachwerte. Audio wird ausschließlich als fremder modaler Anschluss geöffnet/zurückgegeben; Audioinhalte und Stammeskamera-Einstellungen werden nicht verändert.

Der erste eigene Diagnoselauf `36974390769` bleibt insgesamt negativ: ursprünglicher Controls-Verbraucher nach vorheriger Fixture ohne abgeschlossenen Eröffnungslayoutlauf. Die unveränderte Verbraucherroutine besteht im korrigierten frischen Originalaufbau (1600×900/defaults, sechs Layoutframes) sowohl headless als auch nativ; Maus-/Tastaturereignisse und Assertions bleiben erhalten. Der bestehende `graphics_settings_test` bestand im ersten Diagnoselauf auf Windows und Linux mit sauberer SourceRun-Abnahme; er wurde beim reinen Fixture-Folgelauf nicht unnötig wiederholt. Negative Originale und Herkunft stehen unter `reproductions/`.

Spätere Fachliefercommits ergänzen nur Belege/Besitzeranhänge gegenüber der getesteten Fachquelle. `delivery-source-files.json` bindet alle gelieferten ausführbaren Fachdateien bytegenau an den getesteten QA-Tree. Der spätere Dokumenttree wird nicht als erneut ausgeführter kompletter QA-Tree ausgegeben. Nach Übernahme durch R32-01 muss der tatsächliche neue Integrations-/Merge-Tree erneut geprüft werden.

## Eigene Linux-Gegenprüfung

Derselbe Diagnoselauf/QA-Tree besteht auch im Linux-Job `110737151281`: 58 Settings- und 676 Kampagnenkontrollen headless sowie 130 native Settings- und 344 native Kampagnenkontrollen. Wieder 36 Settings- und 50 öffentliche Kampagnenbilder; alle Originalbild-Hashes/Abmessungen positiv, drei kritische native Originalansichten visuell geprüft und bytegleich eingecheckt. Tatsächlicher X11-Displayserver, Godot 4.6.3, Mesa 25.2.8 / llvmpipe LLVM 20.1.2. Logs/Berichte unter `linux/`; [Originalarchiv 11212814164](https://github.com/MajorDragonfly/voxelverse/actions/runs/36975118419/artifacts/11212814164), 21 006 185 Bytes, SHA256 `64cb3bb61288dd2f1726611f469aad5818531161fc5acdb87ef677d3fd22d93a`. Alle 16 Start-/Endmanifeste beider Plattformen sind bytegleich zum einmal mitgelieferten vollständigen Manifest. Linux-Weltaufnahmen auf Software-GL ersetzen ebenfalls keine Ziel-PC-Abnahme.

## Reproduzierbare Befehle nach Anschluss

```sh
python3 tools/review_r32_15_menu.py --godot GODOT --headless --settings-only --output OUT_SETTINGS
python3 tools/review_r32_15_menu.py --godot GODOT --headless --output OUT_CAMPAIGN
python3 tools/review_r32_15_menu.py --godot GODOT --settings-only --xvfb XVFB --output OUT_NATIVE_SETTINGS
python3 tools/review_r32_15_menu.py --godot GODOT --xvfb XVFB --output OUT_NATIVE_CAMPAIGN
```

Auf Windows Editor bzw. vorhandener Anzeige `--xvfb` weglassen. Jeder Runner hält dieselbe exklusive Hostlock über den vollständigen Prozess; bei Belegung Exit 2 ohne Godot. Für die portable Linux-Xvfb-Umgebung werden lokale Shared Libraries über LD_LIBRARY_PATH bereitgestellt. Native Kampagne: zwölf repräsentative Fälle (beide Phasen/Sprachen, 800×600/150, 720p/125, 1080p/100); volle 36 Fälle headless. Native 2D-Settings: vollständige 18er-Matrix, 36 Bilder. Keine kontinuierlichen Videos; pausierte Kampagne rendert nur an Capturegrenzen.
