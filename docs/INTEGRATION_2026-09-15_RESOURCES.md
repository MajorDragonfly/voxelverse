# Integration und prozedurale Ressourcen – 15. September 2026

Auftrag von Lars: neueste Entwicklungen zusammenführen, weitere Entwicklung prüfen,
Beerenbusch und Nest modernisieren. Eigener Branch
`agent/integration-vegetation-nest-20260915`; Basis `d378ca0ecd7f03429a5150df6358e0646ec06689`
(main nach #92). Die folgende Liste ist ein fester Abrufstand, keine Live-Belegung.
Quellen sind ausschließlich die veröffentlichten PR-Köpfe, keine ungesicherten Dateien anderer Chats.

## Zusammengeführte Lieferungen

| PR | Umfang | Übernommener Quellkopf |
|---|---|---|
| [#93](https://github.com/MajorDragonfly/voxelverse/pull/93) | ARCH-13-MANIFEST: Generationenmanifest und Aufbewahrungsplanung | `bc7ab45c4bd0a41bc67101d61200f5d3ac38e57f` |
| [#94](https://github.com/MajorDragonfly/voxelverse/pull/94) | ARCH-17-PUBLISH: Terrain- und Kollisionspublikation aufteilen | `f67853c110b705d5e7b7ecb0af86e8959de1b7e6` |
| [#95](https://github.com/MajorDragonfly/voxelverse/pull/95) | ARCH-25-TRIBE-UI: Dorfübersicht, Aufträge und Berufe DE/EN | `c77be299bb3d3aa4cedb31e1873905a4395a25d5` |
| [#96](https://github.com/MajorDragonfly/voxelverse/pull/96) | ARCH-24-TRUNK: Elefantenrüssel als eigenes Kopfmodul | `3846da5d55b59d91b99b95c985a31bf952371049` |
| [#97](https://github.com/MajorDragonfly/voxelverse/pull/97) | HUD: Vitalwerte an der Minimap und übersichtliche Scanansicht | `bb42e7485a380edd85b7da1ac1bd889549a84989` |
| [#98](https://github.com/MajorDragonfly/voxelverse/pull/98) | ARCH-14-ENCOUNTERS: dauerhafte Tierbegegnungen speicherschonend archivieren | `c0b49ecd17e981a5f01881830727fa9f580d333e` |
| [#99](https://github.com/MajorDragonfly/voxelverse/pull/99) | ARCH-26: zweites produktives Siedlungslager mit Nah-/Fernarbeit | `816fa73d8abdc6fd342486ad0950714dbabb07a5` |
| [#100](https://github.com/MajorDragonfly/voxelverse/pull/100) | ARCH-24-ARTICULATION: bewegliche Kiefer und Krebsscheren | `5d3d6321425f2072daafcb70b3b9c0b968252daf` |
| [#101](https://github.com/MajorDragonfly/voxelverse/pull/101) | ARCH-30-SHIPYARD: modularer Schiffseditor für Expedition und Beiboot | `70e135a17053d11f7a57e516950b06f2211e5703` |
| [#102](https://github.com/MajorDragonfly/voxelverse/pull/102) | ARCH-17-AUDIO: begrenzte Tierbeobachter und saubere Klangquellen | `a89860bd1f96ae7c55c1949f74ec06fcca68e0f6` |
| [#103](https://github.com/MajorDragonfly/voxelverse/pull/103) | ARCH-25-EDITOR: Kreaturenwerkstatt DE/EN und nutzbare kleine Layouts | `38c1687655e2edaf5c4ea436ab4000ef5aa251b6` |
| [#104](https://github.com/MajorDragonfly/voxelverse/pull/104) | ARCH-02-DEVELOPED: Dorf, Tierhaltung und Planetenreisen messen | `58e31d5a29c1751d971b83d958ed5ddb35422d90` |
| [#105](https://github.com/MajorDragonfly/voxelverse/pull/105) | ARCH-24-SNOUTS: Katzen-, Bären- und Schweineschnauzen | `1442aa13a5681cbd1eb3e42ee218a1a2c85e47f6` |
| [#106](https://github.com/MajorDragonfly/voxelverse/pull/106) | ARCH-14-LAB-POPULATION: Tierhistorie im Planetenlabor ohne 256er-Grenze | `5c675ec56dc3eabe2dfb3ee1022133792243f98b` |
| [#107](https://github.com/MajorDragonfly/voxelverse/pull/107) | ARCH-29-CHECK-PLAN: gezielte Tests aus dem tatsächlichen Git-Diff | `0012e49a549b15523b87cd9314ec526181645457` |
| [#108](https://github.com/MajorDragonfly/voxelverse/pull/108) | M10-FOLEY: weichere Schritte und differenzierte Wassergeräusche | `51d4b95ed426569ec7810ae273aec6816a883a7e` |

#105 folgt auf #100. Alle übrigen Lieferungen basieren auf d378ca0. Einzelne PRs
waren als Entwurf veröffentlicht; ihre Fachnachweise und Grenzen bleiben in den
jeweiligen WORK-Dateien erhalten. #99 hatte im PR-Text noch einen laufenden
Abschlusslauf. Der gemeinsame Siedlungs-/Speicherlauf hat inzwischen bestanden:
zwei Orte, getrennte Vorräte, laufende Fracht, Nah/Fern, Pause und frischer Prozess.

## Integrationskorrekturen

- Sprachkataloge anhand ihrer Schlüssel und Testregistry anhand der Vertrags-IDs
  zusammengeführt; PO-Dateien einmal aus dem gemeinsamen Katalog erzeugt.
- Rüssel, zehn Mundformen, Gelenke und übersetzte Werkstatt gemeinsam erhalten.
  Neun fehlende Sprachschlüssel für Kopfkategorie/Rüssel/Katze/Bär/Schwein ergänzt.
- Dorfübersicht behält Sprachwechselzustand und den Zweitortreiter. Fortschritt,
  Karten und Backup-CI erhalten alle unabhängigen Anschlüsse.
- Alte Rüsselprüfung erwartete pauschal sieben Münder. Jetzt werden die zehn
  konkreten Mund-IDs geprüft und der separate Rüssel ausdrücklich ausgeschlossen.
- Die Werkstattprüfung berücksichtigt alle 36 Rezepte einschließlich der drei
  neuen Schnauzen. Der echte alte Eierkampagnen-Spielstand behält sämtliche
  Entdeckungen, Punkte, Freischaltungen und Forschung; sein leeres Begegnungsbuch
  wird ausdrücklich als Übergang von Inline-Schema 1 zu leerem Archiv-Schema 2 geprüft.
- Globales Aufbewahrungsmanifest kannte nur `regions/blobs`. Das Labortierpaket
  verwendet `living_fauna/blobs`. Der Bericht führt beide Speicherbereiche nach
  Pfad; identische Hashes im falschen Verzeichnis ersetzen keinen fehlenden Blob.
  Begegnungen werden mit ihrem vorhandenen Fachvalidator gelesen. Labortierblobs
  werden strukturell geprüft; ihre fachliche Validierung bleibt beim Godot-Lader.
  Die Planung erhält weiterhin alle Dateien und erteilt keine Löschfreigabe.

- `docs/evidence/.gdignore` hält historische Screenshots, Hörproben und Diagnosekopien
  aus dem aktiven Godot-Import heraus. Sie bleiben lesbare Nachweise; das Spiel
  referenziert keine dieser Dateien.

## Beeren und Nest

`resource_visual_factory.gd` nutzt die vorhandene V9-Flora-/Biompalette. Sechs
Strauchformen (verzweigt, aufrecht, Etagen, Fächer, Bogen, Polster) variieren
zusätzlich in Ausrichtung, Proportionen, Kronen und Fruchtfarbe. Seed und feste
Nahrungsidentität bestimmen das Objekt; beim Wiederbesuch oder lokalen Rebase
wird keine neue zufällige Welt erzeugt. Die Kugelkampagne liefert Planetenprofil
und Biom direkt aus ihrer bestehenden Oberflächenquelle.

Früchte sind ein eigenes Mesh. Ernte und Regeneration schalten dessen Sichtbarkeit
um und behalten Laubmesh und Collider. Bisherige Dimensionen der Kollision und
Nahrungs-/Regenerationsregeln bleiben erhalten. Der gemeinsame kleine Voxelbauer
emittiert nur äußere Flächen und verwendet ein gemeinsames Material. Keine
zusätzlichen Nodes pro Voxel und kein unbegrenzt wachsender globaler Meshcache.

Bei der Abschlussprüfung wurde eine verkehrte Flächenreihenfolge im neuen
Meshbauer korrigiert. Der Regressionstest vergleicht sie jetzt mit Godots eigenem
`BoxMesh`; der vorherige Stand scheitert an dieser Prüfung, die Korrektur besteht.
Godot erwartet vorne sichtbare Dreiecke im Uhrzeigersinn
([Godot 4.6: ArrayMesh](https://docs.godotengine.org/en/4.6/classes/class_arraymesh.html)).
Auch der Exportvertrag prüft die Ressourcen und ihren Neustart direkt aus der PCK.

Das Nest hat einen versetzten Zweigrand, eine flache gepolsterte Mulde, kurze
Faserstränge, Blätter in der Planetenpalette und einen niedrigeren Eingang. Die
feste Körper-/Nestkennung ersetzt im Kugelspiel das flüchtige X/Z als Formseed.
Radiale Ausrichtung, Respawn-Marker und Heimat-/Dorfanschlüsse bleiben erhalten.
Die alten Materialien/Geometriegeneratoren sind aus den aktiven Szenen entfernt;
historische Texturdateien werden nicht pauschal aus anderen Quellen gelöscht.

## Weitere Entwicklung

Godot 4.6.3 und die bestehenden Datenbesitzer bleiben die Basis. Im geprüften
Code gibt es keinen Anlass für einen Enginewechsel oder eine pauschale Neuarchitektur.
Die nächsten begrenzten Pakete stehen in `tools/workflow/packets.json`; die sechs
bereits gelieferten Einstiegsaufträge wurden durch konkrete Folgeaufträge ersetzt.

1. Restliche einzelne Terrainaufrufe/Coverwechsel auf dem festen Build messen.
2. Arbeitsplatzinstanzen innerhalb eines Ortes und Transport zwischen den zwei
   Lagern nacheinander anschließen; keine voreilige Erhöhung der Instanzbudgets.
3. Speicherlebensdauer mit aktiven Schreibern vereinbaren; Aufbewahrungsbericht
   ist noch keine sichere automatische Bereinigung.
4. Verbleibende Tierhaltungs-/Epochenkopie und gespeicherte Teilrevisionen bearbeiten.
5. Ziel-PC-Abnahme auf Ryzen 7 9800X3D, RTX 4070 Ti, 32 GB / 5200 MT/s.

Fachchats können jetzt `validate_godot.py --changed-since BASIS_SHA --plan`
verwenden. Unbekannte/zentrale Änderungen erweitern auf die volle Suite. Das
erspart manuelles Nachlesen der Testzuordnung, ohne eine Testfreigabe vorzutäuschen.

## Nachweise und Grenzen

Quell-/Werkzeugstand: `4648ae9a0f3f3f418889da57e806cffba1f24c7d`. Danach folgen
nur diese Übergabe und Nachweise. Alle Ergebnisse und Quelländerungen stehen in
[der Abnahme](evidence/integration-resources-20260915/README.md).

- Alle **179 registrierten Godot-Tests** ausgeführt, nach dokumentierten
  Integrationskorrekturen erfolgreich; zusätzliche Nachprüfungen für die
  Flächenkorrektur und den Ressourcen-Neustart aus dem Export.
- **24** gemeinsame Quell-/Laufzeitprüfungen einschließlich Start,
  Abbruchphasen und Streaming erfolgreich. Separater Import/Art-Check erfolgreich.
- **101 Python-Tests** erfolgreich, **6 optionale Prüfungen** ausgelassen.
  Labortier-Backup zusätzlich nativ mit 388 historischen Identitäten und
  Wiederherstellung ohne Originalverzeichnis geprüft.
- Voller nativer Linux-Lauf am `41deb8c`: **37 Prüfungen** einschließlich
  Produktions-/Reiseketten erfolgreich. Nach der späteren reinen Flächenkorrektur
  neuer Export am `4648ae9` mit **6 gezielten Nachprüfungen** für Start,
  Kugelkampagne, Ressourcen/PCK/Neustart und Meshdaten. Der ältere volle Lauf
  wird ausdrücklich nicht als Vollprüfung des späteren PCK ausgegeben.

Die ursprünglichen Testprotokolle bleiben unverändert, einschließlich der beiden
behobenen Integrationsfehler und der absichtlich roten Flächen-Regressionsprüfung.
Der alte Quellrunner erfasst den Commit erst beim Berichtsschreiben; Startstand,
zwischenzeitliche Änderungen und Nachläufe sind deshalb zusätzlich dokumentiert.

Der Branch ist lokal vorbereitet; GitHub-Veröffentlichung und gemeinsame CI
stehen noch aus. Native Windows-, Grafik- und Ziel-PC-Abnahme sind offen. Der
lokale X-Server kann keine Sockets öffnen. Die beigefügten CPU-Ansichten verwenden
echte exportierte Godot-Meshdaten, sind jedoch keine Spielaufnahmen. Ressourcenansichten
sind in beiden vorhandenen Renderer-Matrizen registriert. Hardware-FPS und
subjektive Spiel-/Hörabnahme können erst auf dem Ziel-PC erfolgen.
