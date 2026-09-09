# Projektbereinigung – 9. September 2026

## Ergebnis und Abgrenzung

Basis: `3a3e0272375e556f3ff65b7370582af79a9d48b5` (integrierter main).
Eigener Branch: `agent/project-maintenance-2026-09-09`.
Der endgültige Commit ist der Kopf des zugehörigen Entwurfs-PRs; alle Nachweise
in diesem Verzeichnis gehören zum selben Bereinigungspaket.

Zwölf nicht mehr referenzierte Prototypen entfernt: **2.523 Zeilen / 71.738 Bytes**.
Das reduziert Altcode, der beim Ressourcenexport noch berücksichtigt werden konnte.
Keine Behauptung eines gemessenen FPS-, Importzeit- oder Paketgrößengewinns.
Die Laufzeit nutzt weiterhin dieselben Generatoren, Modelle und Spielsysteme.

Die Änderung liegt ausschließlich im eigenen Checkout und Branch. Keine fremden
Branches zusammengeführt, gelöscht oder umgeschrieben; kein Merge nach main.
Keine Änderungen an Roadmap, Speicherformaten, IDs, Autoload-Konfiguration,
Kreatureneditor, Journal, Dorfwirtschaft oder aktivem Kugeladapter.
Nicht veröffentlichte Änderungen der sieben anderen Chats sind hier nicht sichtbar;
deshalb bleibt die Integration ein gesonderter Schritt.

## Entfernte Dateien

| Datei | Zeilen |
|---|---:|
| `world/fauna/fauna_streamer_v5.gd` | 149 |
| `world/generation/world_generator_v4.gd` | 271 |
| `world/streaming/chunk_lod_controller_v6.gd` | 55 |
| `world/visuals/scenery/procedural_ecosystem_v3.gd` | 269 |
| `world/visuals/scenery/procedural_ecosystem_v4.gd` | 450 |
| `world/visuals/scenery/terrain_scenic_dressing_v2.gd` | 142 |
| `world/visuals/scenery/voxel_asset_library_v6.gd` | 132 |
| `world/visuals/terrain/landscape_horizon.gdshader` | 20 |
| `world/visuals/terrain/micro_voxel_surface_v5.gd` | 282 |
| `world/visuals/terrain/micro_voxel_surface_v6.gd` | 252 |
| `world/visuals/voxel/voxel_scenery_styler.gd` | 401 |
| `world/world_manager_v2.gd` | 100 |

Für jede Datei wurden Pfad/Basename, GDScript-Klassen, Ressourcen-/Szenenreferenzen,
Tests, Konfigurationen und Erzeugungsskripte geprüft. Auch dynamische Ressourcen-
und Verzeichniszugriffe wurden auf entsprechende Ladewege untersucht.
Es gab im Basisstand keinen eingehenden Code-/Ressourcenverweis.
SHA-256 und Ausgangsgröße jeder Datei stehen in `validation/project-maintenance/audit.json`.

Wiederherstellung einzelner Dateien ist jederzeit aus dem Basiscommit möglich:

```bash
git restore --source=3a3e0272375e556f3ff65b7370582af79a9d48b5 -- <Dateipfad>
```

## Geschützte laufende Arbeiten

Folgende veröffentlichte Fachbranches stammen vom integrierten main:

| Branch | geprüfter Commit |
|---|---|
| `agent/creature-body-contract` | `004d5a62b4010b147a1975ccafa604bada7c5295` |
| `agent/d1-planet-fauna` | `17b23f568dabbec9f3903217238650f0c9178d04` |
| `agent/d2-domestication` | `da6dbd62f505a688aba439cefe42ac8f029da4d4` |
| `agent/interface-audio-task7` | `bd625a1c4cb1687748d44dff37b538fb694ae87f` |
| `agent/m1d-surface-adapter` | `97e9e91a0b5babd10d303df97bfa719224f72300` |
| `agent/m6-village-economy` | `a1b3d7cad8e2ec4661675d14b6e59974b27141fe` |

Keine dieser Lieferungen ändert einen entfernten Pfad oder lädt einen entfernten
Prototypen. D1 nennt elf davon lediglich in einer historischen SHA-256-Inventarliste
(`validation/d1/source-sha256.json`). Das ist ein Nachweis seines damaligen
Quellstands, kein Laufzeitladepfad; dieser Nachweis wurde nicht verändert.
Ältere Vorgängerbranches bleiben unverändert als historische Arbeitsstände erhalten.
Vor späterer Integration neue Fachbranch-Änderungen erneut auf Überschneidungen prüfen.

## Optimierte Prüfwerkzeuge

- `validate_godot.py` erzeugt ohne `--output` einen eigenen temporären
  Ergebnisordner und gibt ihn aus. Gleichzeitige Chats überschreiben so keine Logs.
  Bei explizitem `--output` muss jeder Lauf einen eigenen Zielordner erhalten.
- Daten-, Einstellungs- und Cacheverzeichnisse der Tests werden unter Linux und
  Windows separat gesetzt. Vorhandene APPDATA-/XDG-Pfade werden nicht verwendet.
- Portable Godot-Installationen mit `_sc_` oder `._sc_` werden für die Prüfung in
  eine temporäre, nicht portable Laufkopie überführt. Die installierte Engine,
  ihr Marker und ihre `editor_data` bleiben unverändert. Die Laufkopie wird entfernt.
- Export- und Quellprüfungen nutzen dieselbe `isolated_env`-Implementierung aus
  `tools/validation_support.py`; die Export-Prüfabläufe bleiben erhalten.
- Relative Projektpfade werden normalisiert; Testlogs werden explizit als UTF-8
  geschrieben und können auch unter Windows Umlaute enthalten.

Getrennte Ergebnis- und Benutzerdatenordner ersetzen keinen eigenen Checkout:
**Nicht zwei Importläufe gleichzeitig in demselben Projektverzeichnis starten.**
Die Godot-Importdaten gehören weiterhin zum jeweiligen Checkout.

## Dokumentation korrigiert

Die Startanleitung führt nun über F5 zum konfigurierten Startmenü. Skilltree und
Stammesbeginn sind als vorhanden beschrieben. Die Generator-README benennt V9
als aktiven Autoload und die weiterhin benötigte Vererbung, anstelle einer
veralteten V2-Anleitung mit inzwischen unzutreffenden Tastenhinweisen.

## Prüfungen

Godot **4.6.3 stable**, Linux, headless:

- sauberer Projektimport und Modellquellen-Roundtrip bestanden;
- neun vorhandene Tests bestanden: `world_runtime_continuity_test`,
  `world_evolution_v2_ci_test`, `world_layered_v7_test`, `environment_playtest_test`,
  `water_continuity_test`, `planet_sphere_contract_test`, `gameplay_acceptance_test`,
  `save_slots_test`, `tribal_age_world_test`;
- darin echter Stammesbeginn, Bewohner/Transport und Save/Load auf erzeugtem Terrain;
- zwei echte Godot-Prozesse parallel mit portabler Engine: getrennte Benutzerpfade,
  keine gegenseitig gelesene Sentinel-Datei, temporäre Engine anschließend entfernt;
- zwei vollständige Quellprüfläufe mit `save_slots_test` parallel: beide erfolgreich,
  unterschiedliche automatisch erzeugte Ergebnisordner, relativer Projektpfad geprüft;
- Python-Quellprüfung und `git diff --check` bestanden.

Nachweise: `validation/project-maintenance/` (Audit, Godot-Ergebnisse,
Benutzerdatenisolation und parallele Runner).
Kein neuer Windows-Gesamtexport oder visueller Spieltest; die Änderungen behaupten
keine vollständige Abnahme der parallel entwickelten neuen Funktionen.

## Bewusst behalten

Aktive ältere Vererbungsgrundlagen, bestehende Tests/Fixtures, Modellquellen,
LOD-Stufen/Artenvarianten, Importkonfigurationen und gespeicherte Ressourcen-UIDs
bleiben bestehen. Es gab keine verwaisten versionierten UID-/Importdateien und
keine versionierten EXE-/ZIP-/Python-Cache-Altlasten.

Historische Grafik-/Prüfberichte, Screenshots und vorhandene Windows-Testpakete
bleiben Vergleichs- und Rückfallstände. Alter oder fehlender direkter Spielverweis
allein genügt hier nicht zum Löschen. Weitere Bereinigung in aktiven Fachbereichen
folgt erst nach deren abgeschlossener Integration.
