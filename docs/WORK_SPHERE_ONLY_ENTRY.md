# Kugelwelt als einziger regulärer Spielweg

Stand: 10. September 2026. Grundlage: `main` `350726a696f9cfdac6f16039fd524c9d0777f878`.

## Entscheidung von Lars

Die Flachwelt wird unabhängig von der noch ausstehenden vollständigen Kugelabnahme aus dem regulären Spiel genommen. Die Kugelwelt ist ab jetzt die Grundlage für Tests und Fehlerbehebung. Diese Entscheidung ersetzt die frühere Vorgabe, den Flachstart erst nach M1i/ARCH-19 abzuschalten. Sie erklärt keine offene Grafik-, Gameplay-, Langzeit- oder Leistungsprüfung für bestanden.

## Verhalten

- „Neues Spiel“ startet direkt die gemeinsame `spherical_campaign.tscn`. Der bisherige optionale Kugelhaken entfällt. Auch der Standard von `SaveGameService.create_slot` ist kugelförmig; `SessionFlow.new_game` weist einen ausdrücklich angeforderten Flachstart zurück.
- „Fortsetzen“ und „Abenteuer laden“ führen vorhandene Kugelstände direkt fort. Bei alten Flachständen wird der vorhandene geprüfte Kopierumzug verwendet. Die Quelle bleibt unverändert; wiederholtes Fortsetzen derselben Quelle verwendet dieselbe bereits gespielte Kopie. Die UI erklärt den Kopierweg.
- Unlesbare oder neuere Quellen und nicht unterstützte Migrationen bleiben geschützt und erhalten einen konkreten Fehler. Es gibt keinen Rückfall auf spielbare Flachwelten. Sicherungen und vollständige Originalarchive bleiben über die vorhandene Verwaltung zugänglich.
- `GameState.campaign_scene` verweist für alte Daten auf das Hauptmenü. Der normale Session-Lader akzeptiert ausschließlich die Kugelszene. Kreaturen-/Gebäudeeditoren und das Planetenlabor führen in die gleiche Kugelkampagne zurück; ohne aktive Kugelkampagne zum Hauptmenü.
- Der echte Kugelstart lädt vorhandene Vegetation und Kampagnenpopulation. Die vorhandenen ersten Schritte sind nun auch im Kugel-Pausemenü erreichbar. Die gemeinsame Steuerungshilfe enthält Scanner, Buch, Editor, Karte und Reisen.
- F4 bleibt ein ausdrücklich bezeichnetes technisches Planetenlabor. Es ist keine zweite Kampagne. Sein Rückweg lädt den gesicherten Kampagnenzustand einschließlich Kugelort, statt Labordaten zu speichern.

## Verbleibender Altcode

Die bisherige `main/main.tscn` wurde aus dem Spielordner entfernt und nach `core/diagnostics/legacy_world.tscn` verschoben. Sie wird ausschließlich von ausdrücklich historischen Regressionen und Werkzeugen geladen. Die entsprechenden Referenzen wurden umgestellt. Es gibt keinen Menü-, Fortsetzen- oder Editorweg dorthin. Native Diagnoseargumente sind vom regulären Spielstart getrennt.

Die alten Datenformate, Generator-/Biom-/Assetdienste und gezielten Regressionen bleiben erhalten: Teile dieser Dienste werden auch von der Kugelwelt oder ihrer Migration verwendet. Ihre pauschale Löschung wäre keine Entfernung einer unabhängigen Welt, sondern würde gemeinsame Funktionen entfernen. Neue Inhalte und reguläre Akzeptanzprüfungen gehören auf die Kugelkampagne.

## Prüfung

Der vorhandene Kugelkampagnenprobe prüft jetzt auch den regulären Neuspielstart ohne Auswahlhaken, die Ablehnung eines Flachstarts, tatsächliche Vegetationsinstanzen, automatisches Laden einer alten Quelle über ihre erhaltene Kugelkopie sowie F4 und Rückkehr in dieselbe Kampagne. Die bestehenden Prüfungen für Bewegung, Ursprungskorrektur, Pause, unveränderte Originaldaten und frischen Prozess bleiben enthalten.

Der echte Frontendprobe verwendet die Kugelwelt einschließlich radial ausgerichteter Bewegungs-/Scanprüfungen. Historische Speicher-/GUIprüfstände deklarieren ihre Flachweltdaten ausdrücklich; sie bestimmen nicht den Standard neuer Spiele.

Lokale Abschlussprüfung mit Godot 4.6.3 unter Linux, headless, getrennten temporären Spielständen und strenger Fehler-/Leakprüfung:

| Prüfung | Ergebnis |
|---|---|
| Editorimport und Assetquellen | Bestanden |
| `spherical_campaign_contract_test` | Bestanden: Standard, geschützte Originaldaten, wiederverwendete Kopie und neue/fehlerhafte Formate |
| `spherical_campaign_runtime_test` | Bestanden: regulärer Kugelstart, vorhandene Vegetation, Bewegung, Neustart und F4-Rückkehr; 60,9 Sekunden |
| `frontend_test` | Bestanden: tatsächliche Menüs, radiale Einführung, Pause, Kopie/Verlauf, Fehler beim Speichern und erneutem Laden |
| `menu_input_test` | Bestanden: historische GUI-Prüfszene und Labor verlassen ohne spielbaren Flachwelt-Rückweg |
| `spherical_creature_test` | Bestanden: Kamera-Scan, einmalige Belohnung, normaler F2-Editor, gleiche Heimat, Süßwasser und Audio |
| `spherical_developed_migration_test` | Bestanden: entwickelter Altstand mit tatsächlicher Kugelaktivierung und frischem Prozess |
| `save_slots_test`, `onboarding_test`, `localization_test`, `creature_scan_test` | Alle vier bestanden |
| Historisches Vergleichswerkzeug | Zwei Zyklen mit Aus-/Nachladen und Menü-/Speicherrückkehr bestanden; keine zusätzlichen Nodes, Ressourcen oder verwaisten Objekte nach dem warmen Zyklus. Dies ist ausdrücklich kein Kugel-Leistungsnachweis. |
| Übersetzungskatalog | 233 Meldungen, Deutsch/Englisch, Platzhalter und erzeugte Ressourcen konsistent |

Damit sind zehn gezielte Godot-Tests plus Import-/Assetprüfung bestanden. CI, native Windows-/Linux-Exportprüfung und manuelle Darstellung dieses Commits sind noch nicht ausgeführt. Die Darstellung und Spielbarkeit auf Lars’ Test-PC bleiben die nächsten Arbeitsschritte; 1080p60 und fertige NMS-Skalierung werden nicht behauptet.
