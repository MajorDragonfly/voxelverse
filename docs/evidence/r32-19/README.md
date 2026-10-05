# R32-19 · Bewohnerdetails · #206

Feste Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`,
Tree `f2bda4f815df1c73b9d740ca5282917523faf618`.
Belegung: [#137](https://github.com/MajorDragonfly/voxelverse/issues/137#issuecomment-5946206999).
Draft: [#258](https://github.com/MajorDragonfly/voxelverse/pull/258) → `agent/integration-r32-20261002`.

## Verhalten und konkrete Korrekturen

Weltklick und Bewohnerliste zeigen dieselbe kanonische Bewohner-ID. Die neue
Detailpräsentation löst diese ID bei jedem Refresh aus dem aktuellen Dorfbestand
auf; sie behält weder Member-Dictionaries noch Actor-Referenzen. Name, Beruf/Auftrag,
Nahrung/Wasser, Fracht und zugewiesener Arbeitsplatz werden getrennt gelesen.
Gesundheit stammt nur vom gültigen geladenen Actor dieser ID. Fehlender, gelöschter
oder falsch zugeordneter Actor liefert keinen erfundenen Gesundheitswert.
Mehrfachauswahl sowie fehlende/doppelte IDs ergeben kein Einzelblatt.

Im Basisdetail fehlen Gesundheit und Arbeitsplatz; beim Tragen wird der Auftrag
von der Frachtbezeichnung verdrängt. Das neue Blatt zeigt beispielsweise zugleich
„sammelt Holz / gathering wood“ und „Fracht · Holz / Cargo · wood“. Die Kugelbilder
belegen diesen Zustand mit tatsächlich aufgenommenem Holz.

Die erste neue Arbeitsplatzbeschriftung verwendete beim fertigen Brunnen noch
„Brunnenbau / Well construction“. Die nativen Vorherbilder unter `logs/well-caption-before-*.png`
belegen das. Die Korrektur verwendet den vorhandenen Gebäudenamen „Brunnen / Well“;
18 genaue DE/EN-Textvergleiche und die finalen Bilder sichern sie ab.
Gesundheits-/Baumaterialhinweise nehmen jetzt am Tooltip-Hitpfad teil, während der
Detailcontainer Weltklicks weiterhin abfängt.

Persönliche Werkzeuge/Kleidung sind im vorhandenen Besitzmodell nicht erfasst.
Die Anzeige kennzeichnet beide als derzeit nicht verfügbar. Gemeinsamer Dorfbestand,
`tribe.tools` und ungeprüfte zusätzliche Member-Keys werden nicht zu persönlichem
Besitz erklärt. Es gibt kein neues Inventar-, Controller-, Schema- oder Savesystem.

## Besitzeranschlüsse

Eigene Dateien: `ui/tribe/resident_details_*`, `tests/r32_19_*`,
`tools/review_r32_19_*` und dieses Evidence-Verzeichnis. Gemeinsame Hostdateien
bleiben im Fachbranch unverändert.

- `patches/tribe-panel.patch`: enger Detailaufbau-/Refreshanschluss an R32-14/R32-01.
  Die alten sieben Label-/Meterports bleiben als Aliase erhalten. Der Auftrag wird
  neben der Fracht angezeigt. Seriell auf R32-14s aktuellen HUD-Stand übertragen;
  `git apply --check` gilt für die feste Basis.
- `patches/localization-append.json`: neun DE/EN-Nachrichten genau einmal an den
  zentralen Katalog anhängen, danach `python3 tools/localization/catalog.py`.
- `patches/test-registry-append.json`: beide neuen Tests genau einmal unter `village`
  registrieren. Keine Registry/PO-Datei wird aus dem Fachbranch ersetzt.

Die Tests installieren die ausstehenden Texte nur in ihrer isolierten Testumgebung.
Controller-/Schema-/Saveanschlüsse bleiben R32-01. Auch die gemeinsame Arbeitsplatzliste
benutzt auf der festen Basis für den Brunnen noch die Bau-Bezeichnung; den Abgleich
außerhalb des zugeordneten Details bitte bei R32-14/R32-01 vornehmen.
Der optionale Diagnoseworkflow liegt ausschließlich auf
`agent/r32-19-evidence-20261002`, nicht im Fach-PR.

## Abschließende Originalprüfung

[Positiver Gesamtlauf 36977475139](https://github.com/MajorDragonfly/voxelverse/actions/runs/36977475139).
Godot `4.6.3.stable.official.7d41c59c4`, Ubuntu 24.04 GitHub-Runner,
Mesa 25.2.8 llvmpipe / OpenGL 4.5 Compatibility, Seed 15838.

Feste Fachquelle `29bbc67d3aa00f964ac4cbee61b70470201486b6`,
Tree `b798d3bd618b7cc4ddd2990dc93288984df998ee`.
Sauberer QA-Overlay-Commit `2f4cb6ab08c8f0fdcd892057765ae91d82e72179`,
Tree `829f8b451029ec5890701fbb93affd3ca5b1fbb3`: ausschließlich die erklärten
Host-/Katalog-/Registryanschlüsse wurden zusätzlich seriell angewendet.
`delivery-code-audit.json` vergleicht alle 16 eigenen Produkt-/Test-/Review-/Anschlussdateien
mit dem Original-Quellmanifest. Danach wurden nur Dokumentation und Belege ergänzt.
Ein neuer Integrationsbaum braucht seine eigene Prüfung.

| Abschnitt | Ergebnis | Nachweis |
| --- | --- | --- |
| Modell | 19/19 | Echte VillageWork-Arbeit/Lieferung/Verbrauch, JSON-Restore, Actor-Lifecycle, autoritative Fernarbeit und Near-Ownership-Sperre |
| Vollständige Headless-UI | 475/475 | Echte Controller/Maus, Liste/Welt, Shift-Mehrfachauswahl, leerer Treffer, lebender Raubtier-Actor, Holz/Stop, Wasser/Trinken, Arbeitsplatz, Save/Load und frischer Godot-Prozess |
| Bestehender Sprachverbraucher | positiv, 970 Kontrollen | `tribe_localization_test`, alte Detailports und DE/EN |
| Native Fixture | 511/511, 36 PNGs | Dieselben Fachhandlungen, 18 Größen-/Skalierungs-/Sprachfälle, Scroll-/Klickprüfung, echter Cold Process |
| Reguläre Kugelkampagne | 25/25, 5 PNGs | Titel → öffentlicher Kugel-Playtest → tatsächliche Bestätigung, Welt/Listenauswahl, Holzfracht, Pause, Save → Titel → Load |

Fokussierter Befehl: `validate_godot.py --tests r32_19_resident_model_test
r32_19_resident_ui_test tribe_localization_test --skip-main` mit Godot-Import.
Native Fixture: `review_r32_19_residents.py` unter Xvfb; Kugelprobe:
`review_r32_19_world.gd` unter Xvfb. Vollständige Befehle, Enginepfade, isolierte
Umgebungen und Logs stehen in `remote-final/*/results.json` und den Originalprotokollen.
Alle drei Abschnitte sind sauber, unverändert und SourceRun reusable; der strenge
ERROR-/Leakfilter ist positiv. Keine Simulation-/Saveassertion wurde gelockert.

`remote-final/artifact.json` enthält ZIP- und Einzelbildhashes; Originalartefakt
11214495543, ZIP SHA256 `acd611e5a14cbfa84f6e2c110d0c97de9d327b6a5be99e3a1207afd1fd6ff706`.
Alle 41 PNGs sind unverändert enthalten. Die Quell-JSONL und umfangreichen Importlogs sind verlustfrei mit gzip
(mtime=0) komprimiert; die Original-Resultdateien beziehen ihre Hashes auf die
entpackten Originaldateien. Es wurde kein Screenshot retuschiert oder nachgebaut.

## Bedienbilder

[Alle Fixture-Bilder](remote-final/native-fixture/) und
[alle Kugelbilder](remote-final/native-sphere/).
Die Fixture zeigt absichtlich den wörtlichen Namen `TRIBE_BOOK {count}`: Er bleibt
über beide Sprachen und den frischen Prozess identisch, statt als Textschlüssel
übersetzt zu werden. Die Kugelbilder zeigen den normalen Gefährtennamen.

| Bedienfall | DE | EN |
| --- | --- | --- |
| 720p / 100%, zugewiesener fertiger Brunnen | [DE](remote-final/native-fixture/resident-1280-100-de-bottom.png) | [EN](remote-final/native-fixture/resident-1280-100-en-bottom.png) |
| 1080p / 150%, unterer Detailbereich | [DE](remote-final/native-fixture/resident-1920-150-de-bottom.png) | [EN](remote-final/native-fixture/resident-1920-150-en-bottom.png) |
| Reguläre Kugel, tatsächliche Holzfracht | [DE](remote-final/native-sphere/sphere-resident-de-bottom.png) | [EN](remote-final/native-sphere/sphere-resident-en-bottom.png) |
| 800×600 / 150%, scrollbar erreichbare Ausstattung | [DE](remote-final/native-fixture/resident-800-150-de-bottom.png) | [EN](remote-final/native-fixture/resident-800-150-en-bottom.png) |

Die vollständige Matrix enthält 800×600, 1280×720, 1920×1080 ×
100/125/150% × DE/EN, jeweils oberen/unteren Ausschnitt. Alle Detailzeilen werden
über den echten Scrollcontainer erreicht und Klicks aus dem Detail behalten die
Auswahl. Die Fixture hat einen vorgebauten Brunnen und kontrollierten Durst;
Wasserproduktion, Weg, Lagerlieferung und Trinken folgen anschließend dem normalen
Fachpfad. Das ist keine Abnahme des Brunnenbaus. Der Kugellauf enthält weder diesen
vorbereiteten Brunnen noch künstlich zugesetzte Holzfracht.

## Erhaltene negative Originale und Prüfhelferkorrekturen

- `logs/initial-freed-actor-negative.log`: eigener erster Helper dereferenzierte
  einen gelöschten Actor im `is`-Check. Gültigkeitsprüfung vorgezogen; Lifecycle-Test positiv.
- `logs/fixture-prerequisites-negative.log`: ursprüngliche Fixture ohne Brunnen/
  Durst konnte nicht trinken. Vorbedingungen berichtigt, keine Produktregel geändert.
- `logs/fixture-freeze-negative.log`: eigene UI-Freeze blockierte Reload-Navigation.
  Probe löst ihre Freeze vor Load. Kein Save-/Navigationsfix behauptet.
- `native-display-negative/`: lokaler Xvfb kann keine Unix-/Local-Sockets öffnen;
  kein DisplayServer, null Bilder, Abbruch/Leakfilter negativ. CI benutzt einen
  unabhängig funktionierenden nativen Host. Alle späteren lokalen Godot-Läufe
  hielten den R32-Mutex; nach Rückgabe des Slots keine weiteren lokalen Godot-Läufe.
  Frühe leichte Läufe bleiben mögliche Fremdlast in R32-02s Original; keine FPS-Aussage.
- `remote-first-negative/`: ursprüngliche native Stop-Probe erreichte während der
  Klickvorbereitung bereits die Lieferung; beobachtete Cargo-Grenze wird jetzt
  vor der Vorbereitung eingefroren. Kugelhelfer prüfte zu früh die angeforderte
  Load-Szene; er wartet nun auf den bestehenden begrenzten Load-Watchdog.
- `remote-layout-negative/` und `remote-scroll-negative/`: erster 800×600-Headless-
  Scrollzustand blieb mit dem Namen oberhalb des Viewports. Zusatzwartezeit allein
  half nicht. Eigener Helfer folgt jetzt begrenzt den aktuellen physischen Rechtecken;
  dieselbe vollständige Sichtbarkeitsassertion bleibt bestehen. Native Teilprüfungen
  dieser Läufe bleiben gesondert positiv; kein positiver Gesamtlauf daraus abgeleitet.

Die vollständigen Nichtbild-Originale, Resultate und Quellmanifeste dieser roten
CI-Läufe bleiben erhalten; Bilder sind über Originalartefakt-ID und Einzelhash
identifiziert. Die zwei falschen Brunnenbeschriftungen liegen zusätzlich als PNG vor.
Die alte lokale Fachprüfung (19/452/970) steht weiterhin unter `focused/` und ist
historisch; maßgeblich ist die abschließende Quelle unter `remote-final/`.

## Verbleibende Modell-/Ziel-PC-Lücken

Persönlicher Werkzeug-/Kleidungsbesitz, Slotzuweisung und Speicherung fehlen.
`HomeCompanion.current_health/maximum_health` existieren am geladenen Actor,
aber `TribeState.members` hat keinen gespeicherten Gefährten-Gesundheitsport.
Beim bestehenden Wiederaufbau wird Actor-Gesundheit neu initialisiert. Das Detail
liest den tatsächlichen aktuellen Wert und erklärt diese Grenze im erreichbaren
Tooltip; es repariert das fehlende Modell nicht innerhalb einer Anzeigeaufgabe.
Diese Besitz-/Gesundheits-/Save-/Fernanschlüsse brauchen eine gesonderte Abstimmung
mit R32-01 und den Modellbesitzern.

Fernarbeit/Near-Ownership sind auf Modellebene geprüft. Ein vollständiger sichtbarer
Planet-Reise-/Nah-Fern-Rückkehrablauf mit allen Detailfeldern gehört noch in die
kombinierte Integrations-/Ziel-PC-Abnahme. Feindlicher Treffer ist mit einem echten
Raubtier-Actor in der ausdrücklich flachen Fixture geprüft, nicht als kombinierte
feindliche Kugelbegegnung mit Reise beworben.

150% ist hier ein Laufzeitwert. Die Basis begrenzt den gespeicherten Neustart-/
Einstellungsport noch auf 135%; dessen Änderung gehört R32-15/R32-01.
Windows/Lars' Ziel-PC, GPU-Leistung, native Exporte, volle Suite und der gemeinsame
Merge-Tree sind nicht abgenommen. #206 bleibt offen; #258 bleibt Draft.
