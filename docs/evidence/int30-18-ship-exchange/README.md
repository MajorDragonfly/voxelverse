# INT30-18-SHIP-EXCHANGE

Feste Fachbasis: `2b1ac023db4074c2ce6b7db8fbab09ab929a8435`, Tree
`5f815f478ceeabefcfc50a6388e3e4b0daa2ac45`. Eigener Branch:
`agent/int30-18-ship-exchange`. PR-Ziel: `agent/integration-pt19-20260930`.
Die zentrale Zuordnung bleibt in Issue #137; dies ist eine Fachübergabe.

## Öffentliche Schnittstellen

| Datei / Aufruf | Wirkung |
|---|---|
| `ship_blueprint_package.export_blueprint(blueprint, metadata)` | Positive Feldprojektion eines gespeicherten Schiffs (`revision >= 1`). Reine Kopie. |
| `inspect(package)` | Geschlossene rekursive Struktur, Identität, vorhandene Ship-/Assembly-Prüfung, lokale Modulrevisionen, Maße. Liefert native `preview`, lokal abgeleitete `evaluation`, `ready`. |
| `prepare_import(package)` | Native Entwurfskopie mit geprüfter Herkunft. Ändert weder Dateien noch Spielstand. |
| `decode(text)` / `read_file(path)` | Begrenztes JSON, vollständig geprüft. |
| `write_file(destination, package)` | Atomarer, unveränderlicher Export; identische Datei ist Leerlauf. |
| `ship_design_exchange.export_file(native_path, destination, metadata)` | Liest den bestehenden gespeicherten Schiffsentwurf und exportiert ihn. |
| `import_file(source, directory=Ship.DIRECTORY)` / `import_package(package, directory)` | Importiert eine neue native Datei in die vorhandene lokale Schiffsautorenbibliothek. Gleiche ID/Revision wird im ganzen begrenzten Ordner geprüft. |

Ergebnisse enthalten `ok`, stabile `code`-Kennung, gegebenenfalls `field`/`error`,
bei erfolgreichem Import `path`, `blueprint`, `ready`. Es gibt keine Szenen-,
Flotten-, Reise-, Freischaltungs- oder Bauaktion. Fracht, Besatzung und Instanz-IDs
sind ausgeschlossen. Ein Import erzeugt kein Schiff und gewährt keine Ressourcen.

## Paket und Grenzen

Eigenes Austauschformat `schema=1`, `kind="ship"`, `payload_schema=1`,
`catalog_revision=1`. `design_id` und positive `revision` stimmen mit dem nativen
Payload überein. Die Feldliste erhält Name, Rolle, Rasterpräferenzen, Teil-UIDs,
Modul-ID/-revision, Position, Drehung, Skalierung, Spiegelgruppe, Socket und Tags.
Die Anforderungen sind eine sortierte eindeutige Modulliste; Anzahl und unabhängige
Identitäten der gleichen Module bleiben in `parts` erhalten.

Nur `title`, `description`, `author`, `tags` sind öffentliche Metadaten. Maximal
acht Quellen sind zulässig. Die Herkunftserweiterung
`extensions["org.voxelverse.ship_exchange"]` im lokalen Entwurf enthält die
ursprüngliche Quellreferenz, bisherige Herkunft und öffentliche Metadaten. Ein
unveränderter Rückexport reproduziert das Paket. Eine neue lokale Variante führt
die Quelle weiter; sie übernimmt deren Autor nicht als eigenen Autor.
Autorangaben sind ungeprüfte Angaben und verleihen keine Rechte oder Konten.

Beliebige native `metadata`, `extensions`, Inventare, Weltorte, Besitzer,
Fortschritt, Code/Assetpfade und Fähigkeiten werden nicht transportiert.
Unbekannte Felder im eingehenden Paket werden vor Normalisierung abgewiesen.
Farben sind auf der festen Fachbasis ausschließlich Modulkatalogfarben; es gibt
keinen nativen individuellen Schiffsfarbvertrag. Die Tests vergleichen deshalb
die tatsächlich vom vorhandenen MeshBuilder erzeugten Vertexfarben. Ein erfundenes
Downloadfeld `color` ist ungültig. Kein Umbau des Schiffs-/Farbschemas.

Grenzen: 2 MiB vor dem Dateieinlesen, 128 Module, ganze Meterpositionen bis 200 m
je Achse, Vierteldrehungen um Y, Skalierung genau eins; vorhandene Rumpfmaßlimits
für Expedition/Beiboot. 120 UTF-8-Bytes für Identität/Name/Titel/Autor und lokale
Socket-/Spiegelkennung, 2.000 für Beschreibung, zwölf Tags zu je 40 Bytes.
Revisionen bis `9007199254740990`; vollständige JSON-Präzision über AtomicJson.
Der Zielordner wird mit höchstens 256 Einträgen untersucht; kein unbeschränkter
globaler Bibliotheksindex. Zielordner/-pfad kommen vom lokalen Aufrufer; aus dem
Payload gelangt nur ein SHA256 der Identität und Revision in den Dateinamen.

Unbekannte und alte nicht unterstützte Versionen, unbekannte Modulkennungen,
fehlende Ursprungsmodule, Doppel-UIDs, Rollenverstöße, Überlappungen und übergroße
Entwürfe werden abgewiesen. Sichere unvollständige Entwürfe bleiben bearbeitbar:
`ready=false`, vorhandene Fachfehler stehen in `evaluation.issues`; `Ship.pin`
verweigert weiterhin die Verwendung als fertiges Schiff. Downloads behaupten
keine eigenen Katalogfähigkeiten oder Hangargeometrien.

## Original- und Revisionsschutz

Keine Revisionsanhebung beim Import, kein Überschreiben bestehender Entwürfe.
Neue Revisionen erhalten separate native Dateien. Identische Importe sind
byteerhaltende Leerlaufvorgänge, auch nach Umbenennung einer lokalen Datei.
Eine abweichende Veröffentlichung derselben Kennung/Revision wird abgewiesen.
Ein beschädigtes/neueres/unlesbares Original im Zielordner blockiert den Import,
weil dann die Eindeutigkeit nicht sicher geprüft werden kann. Kein Backup-Rückfall.
Symlinks im Zielordner werden nicht als sichere lokale Originale behandelt.
Vor einem Schreibversuch werden alle Konflikte geprüft. Die Veröffentlichung
nutzt unverändert DesignStore/AtomicJson, nicht einen eigenen Codec oder Save.
Echte Staging-/Rename-Fehler veröffentlichen keine Entwurfsrevision.

## Patches an Besitzer

- `registry.patch`: Chat 1 registriert `ship_design_exchange_test` genau einmal
  unter `expedition_design`. Keine zweite Registrierung unter `blueprints`.
- `shipyard.patch`: Chat 15 erhält zwei enge Methoden für bestätigte Dateiauswahl.
  Export nur ohne ungespeicherte Änderungen; Import stellt nur einen lokalen
  Bibliotheksentwurf bereit. Vor Bearbeitung die vorhandene Kopierspeicherung
  verwenden. Dateidialoge/Buttons/Bestätigung bleiben beim Werftbesitzer. Der reine
  Additionspatch wird mit `git apply --unidiff-zero` angewendet.
- `localization.patch` / `localization-append.json`: Chat 1 erhält DE/EN für
  Austauschaktionen und sämtliche neuen Fehlerkennungen. Das Append-Payload
  eignet sich für additive Integration nach anderen Sprachlieferungen; danach
  die bestehenden Sprachgeneratoren ausführen. Vorhandene `ship.*`-Fachfehler
  zeigt Chat 15 über seinen Werft-Präsentationsanschluss.

Keine dieser Besitzerdateien ist auf diesem Fachbranch geändert. Die Patches
sind Vorschläge und keine Behauptung eines bereits verfügbaren Werft-UI-Ablaufs.

## Prüfbeleg und Grenzen

`ship_design_exchange_test` prüft echte Dateien, getrennte Nutzerverzeichnisse
und frische Prozesse: Sender → Empfänger → erneutes Öffnen ohne Transferdatei.
Für Expedition/Beiboot und alle Vierteldrehungen werden native Kennungen,
Revisionen, Modulanzahlen/UIDs, Meshvertex-/Farbdigests, lokal berechnete Fähigkeiten,
Abmessungen, Hangarrahmen sowie gedrehte/versetzte Hangarentscheidungen verglichen.
Zusätzlich Versions-/Feld-/Modul-/Byte-/Größen-/Ordnerlimits, widersprüchliche und
doppelte Revisionen, tatsächliche Staging-/Rename-Schreibfehler, Retry und
unveränderte Original-/Kampagnenbytes. Separate Prüfung bestehender Verbraucher
erhält die Grenzen des gemeinsamen Schiffs-/Flottenvertrags.

Die Registry ist dem Integrationschat vorbehalten. Reproduzierbarer Fachlauf:
in einer isolierten Kopie dieses Fachkopfs **nur** `registry.patch` anwenden und
mit Godot 4.6.3 ausführen:

```sh
git apply docs/evidence/int30-18-ship-exchange/registry.patch
python3 tools/validate_godot.py --changed-since 2b1ac023db4074c2ce6b7db8fbab09ab929a8435 --plan --summary
python3 tools/validate_godot.py --godot /path/to/godot --tests ship_design_exchange_test shipyard_test fleet_runtime_test expedition_contract_test blueprint_contract_test modular_assembly_framework_test community_blueprint_package_test --skip-main --output /outside/project/ship-exchange-checks
```

Die Fachprüfung ist kein FULL-Merge-Gate, nativer Export, Render-/UI- oder
Ziel-PC-Nachweis. Patches für Werft/Sprachen sind noch nicht produktiv angeschlossen.
Normale Weltraumfreischaltung, Flug/Kollision, Preise, Crew-/Frachtabläufe und
individuelle Schiffsbemalung bleiben bei ihren bestehenden Fachbesitzern.
