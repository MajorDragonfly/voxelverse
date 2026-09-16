# Godot und die nächste Skalierungsstufe

Bewertung vom 15. September 2026 auf `main` `c8b83f4` (PR #90). Statische
Codeprüfung und vorhandene Messnachweise; kein neuer GPU-/Windows-Benchmark.

## Fortschreibung nach der zweiten Integrationsrunde

Der gemeinsame Kandidat #93–108 ergänzt die erste aufgeteilte Publikation,
Aufbewahrungsplanung, die Begegnungs-/Labortierarchive und zwei produktive Orte.
Die unten datierten offenen Punkte sind daher teilweise geliefert. Konkret
verbleiben einzelne Engineaufrufe/Coverwechsel, Schreiberkoordination und spätere
Bereinigung, Arbeitsplatzinstanzen innerhalb eines Ortes sowie Warenwege zwischen
Lagern. Die Integration korrigiert zusätzlich die Zuordnung des separaten
Labortier-Blobverzeichnisses und ersetzt den Mesh-/Colliderneubau bei Ernte durch
eine Fruchtsichtbarkeit. [Aktueller Umfang](INTEGRATION_2026-09-15_RESOURCES.md).

## Entscheidung

**Godot bleibt die Engine.** Der vereinbarte Singleplayer-Umfang mit festen
Kugeloberflächen, begrenzter Nahsimulation und erlaubten kurzen Orbitübergängen
rechtfertigt derzeit keinen Enginewechsel. Das ist eine Architekturentscheidung
auf Basis des vorhandenen Codes, keine Zusage einer beliebig großen gleichzeitig
aktiven Welt oder einer bereits erreichten No-Man's-Sky-Leistung.

Godot 4.6.3 bleibt für diese Integrationsrunde fest gepinnt. Ein Versionswechsel
bekommt einen eigenen Branch mit Import, Physik-, Shader-, Save- und Exportprüfung.
Eine neue Engineversion löst unbeschränkte Datenmengen oder teure einzelne Uploads
nicht automatisch. UI, Inhalte und Spielregeln können in GDScript bleiben.

## Was bereits trägt

| Baustein | Vorhandener Anschluss | Konsequenz |
|---|---|---|
| Große Koordinaten | `core/campaign/surface_context.gd`, `world/space/cube_sphere.gd`, `world/surface/radial_surface_adapter.gd` | Körperfeste Adressen erhalten; erst nach Abzug des lokalen Ursprungs in Vector3 umwandeln |
| Terrain | `world/planet_lab/planet_patch_job.gd`, `adaptive_sphere_tiles.gd` | CPU-Arbeit nutzt Worker; Meshes/Kollision bleiben kontrolliert am Hauptthread |
| Begrenzte Szene | 12 aktive Tiere, 16 Nahrungspflanzen, höchstens 2 Spawnversuche im Populationshost | Weltgröße durch Daten und Streaming erweitern, nicht durch unbegrenzt viele Nodes |
| Dauerhafte Welt | Regionsblobs, Kartenarchive, präziser JSON-Writer, feste Speicherteilnehmer | Weitere Register an vorhandene Speicherverträge anschließen |
| Fernarbeit | Gemeinsame Aufträge, Fracht und Übergaben | Entfernte Orte als Daten simulieren; Produktion nur durch einen Besitzer |

Godot verwendet standardmäßig 32-Bit-Vektoren, während GDScript-`float` 64 Bit
hat. Die vorhandene Trennung von dauerhafter Adresse und lokalem Vector3 passt
zu großen Planeten. Ein Double-Precision-Build hätte Speicher-/Leistungskosten
und benötigt passende eigene Editor-/Exportbinaries; ihn erst erwägen, wenn eine
konkrete Präzisionsmessung mit dem lokalen Ursprung scheitert.
[Godot: große Weltkoordinaten](https://docs.godotengine.org/en/stable/tutorials/physics/large_world_coordinates.html).

## Nächste technische Arbeiten

1. **Publikationsspitzen messen und begrenzen (ARCH-17/02).** Der Code erlaubt
   zwei Uploads pro Frame mit einem kooperativen Budget von 4 ms. Dieses Budget
   kann einen einzelnen teuren Upload nicht unterbrechen. Worker allein beseitigen
   damit noch keine Frame-Spitze. Mesh-/Shape-Erzeugung, kalten Start und Rückweg
   getrennt messen; Batchgröße oder Veröffentlichung am belegten Engpass ändern.
2. **Speicherlebensdauer schließen (ARCH-13/14).** Ein global begrenztes Manifest,
   erreichbare Blobgenerationen und begrenzte Register fehlen noch als vollständige
   Langzeitlösung. Erst Referenzen aller Saves/Backups/Slots erfassen, danach
   Aufbewahrung und sichere Bereinigung anschließen. Bestehende Archive behalten.
3. **Mehrere Orte am vorhandenen Vertrag beweisen (ARCH-26/27).** Zwei gleichartige
   Arbeitsplätze mit getrennten IDs und Fracht über Nah/Fern/Neustart liefern.
   Bewohner-/Siedlungsgrenzen anschließend anhand der Messung erhöhen.
4. **Auf dem Referenz-PC messen (ARCH-19).** 1080p60 bleibt vorläufiges Ziel.
   Lars' Hardware steht in [PROJECT_STATUS](PROJECT_STATUS.md). Preset, Treiber,
   Build und Route beim Lauf dokumentieren; p95/p99 und Einzelspitzen,
   RAM/VRAM, kalten Start, Speichern und Rückreise bewerten. Die alten ARCH-02-
   Speicherfälle zeigen wachsende Kosten, sind aber keine Messung dieses neuen
   Builds unter voller Grafik-/Dorfbelastung.

Für viele gleichartige Pflanzen sind räumlich getrennte MultiMeshes ein
geeigneter Ausbaupfad: Godot kann deren Instanzen gesammelt zeichnen, besitzt
aber kein individuelles Frustum-Culling innerhalb eines MultiMesh. Die
Gruppierung muss deshalb zum Streaming passen.
[Godot: MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).

Worker dürfen den aktiven Szenenbaum nicht unkontrolliert verändern. Die
vorhandene Trennung zwischen CPU-Daten und Publikation bleibt verbindlich;
ein Thread-Schalter ist keine pauschale Beschleunigung.
[Godot 4.6: Thread-Sicherheit](https://docs.godotengine.org/en/4.6/tutorials/performance/thread_safe_apis.html).

Falls nach Profiling ein CPU-Algorithmus wie Meshing dauerhaft dominiert, kann
genau dieser Kern hinter dem vorhandenen Datenvertrag als C++-GDExtension
implementiert und gegen den GDScript-Pfad gemessen werden. Godot unterstützt
native Bibliotheken über GDExtension ohne vollständige Neuimplementierung des
Spiels. Zusätzliche Build-/Exportpflege muss den gemessenen Gewinn rechtfertigen.
[Godot 4.6: GDExtension](https://docs.godotengine.org/en/4.6/tutorials/scripting/gdextension/what_is_gdextension.html).

## Später gesondert entscheiden

Online-Baupläne benötigen zusätzlich einen Dienst für Katalog, Upload, Versionen
und Inhaltsprüfung. Das ist eine Produktkomponente neben Godot. Allgemeines
Graben/Tunnelsystem, Multiplayer-Simulation oder frei begehbare bewegte
Schiffsinnenräume wären neue Architekturaufträge; sie sind derzeit nicht die
Grundlage dieser Bewertung. Ein pauschaler ECS-Umbau ist nicht vorgesehen.

Messhistorie bei Bedarf: [ARCH-02](ARCH02_MEASUREMENTS_2026-09-10.md),
[Terrainvorausschau](WORK_ARCH17_TERRAIN_LOOKAHEAD.md). Aktuelle Aufgaben werden
über [PROJECT_STATUS](PROJECT_STATUS.md) und den Paketkatalog vergeben.
