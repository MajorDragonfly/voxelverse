# R32-06 — Licht in der tatsächlichen Kampagne (#168)

Basis: `2a738a4891a8de11d682c469833ade4dc9b01dfb`, Tree
`f2bda4f815df1c73b9d740ca5282917523faf618`. Auftrag und Besitzgrenzen:
[Issue #137](https://github.com/MajorDragonfly/voxelverse/issues/137),
[Issue #168](https://github.com/MajorDragonfly/voxelverse/issues/168).

## Ergebnis und Grenze

**Belegter Produktionsfehler:** Der Nachthimmel war bei identischen Bedingungen
in Compatibility fast schwarz, in Forward+ blau. Drei rohe Nachtfarbkonstanten
im Sky-Shader durchliefen die unterschiedlichen Farbraumpfade der Renderer.
`campaign_atmosphere.gd` bindet jetzt die bisherigen linearen Farben als sRGB
kodierte `Color`-Werte an `source_color`-Uniforms. Dadurch bleibt die bestehende
Forward+-Nacht erhalten; Compatibility erhält einen sichtbaren Nachthorizont.
Tagesfarben, Sonnenlicht, Ambiente, Weißpunkt und gespeicherte Belichtung sind
unverändert. Der bestehende Atmosphärentest prüft die drei kalten Bindungen.

Die vorhandene Tageslichtkorrektur hält am tatsächlichen Schneehang Stufen und
Steinstruktur sichtbar. Die Komponentenmessung begründet keine zusätzliche
globale Abdunklung. Materialarbeit bleibt R32-08/09, normale Wetterplanung
R32-18 und Grafikseitenanschlüsse R32-15. Keine fremde Produktionsdatei wird
geändert. Das vorhandene unterschiedliche HUD-Layout ist sichtbar und gehört
zum Grafikseiten-/Skalierungsanschluss, nicht zu dieser Lichtkorrektur.

**Software-GPU-Messungen sind keine Ziel-PC-, FPS-, Export- oder Gesamtfreigabe.**
Die Ziel-PC-Abnahme und die vollständigen Integrationsprüfungen bleiben offen.

## Vergleich, Messwerte und geprüfte Quelle

[Ergebnisse und vollständige Kostentabellen](RESULTS.md),
[maschinenlesbarer Vergleich](comparison/comparison.json),
[Quellen, CI- und Artefakthashes](sources.json).

| Feste Himmelsregion `(280,70,600,130)`, Heimat-Nacht | Basis | Korrektur |
| --- | ---: | ---: |
| Compatibility, mediane sRGB-Luminanz | 0,000000 | 0,147525 |
| Forward+, mediane sRGB-Luminanz | 0,176344 | 0,176344 |

Der verbleibende Unterschied zwischen den Renderern wird ausgewiesen und nicht
als pixelgleiche Darstellung behauptet. Die RGB-Mediane sind Compatibility
`[0,0,0]` → `[0,0980;0,1490;0,2784]`, Forward+
`[0,1373;0,1765;0,2902]` → unverändert. Die HUD-freie Terrainregion behält in
Wald, Schnee, Wasser und Heimat ihre Tag-/Nachtmediane; die Kreatur-Nahansicht
hat geringe verbleibende Pose-/Geometrieunterschiede. Beide Nächte bleiben dunkel,
Hügel, Ufer und Kreaturkonturen sind sichtbar; dunkle Körperinnenflächen sind
keine umfassende Spielbarkeitsfreigabe aller Kreaturen.

Godot 4.6.3: Der offizielle [GLES-Sky-Pfad](https://github.com/godotengine/godot/blob/4.6.3-stable/drivers/gles3/shaders/sky.glsl)
konvertiert die Sky-Ausgabe vor Tonemapping nach linear; der
[RD-Sky-Pfad](https://github.com/godotengine/godot/blob/4.6.3-stable/servers/rendering/renderer_rd/shaders/sky.glsl)
übergibt die lineare Farbe an den HDR-Pfad. Diese Quellbeobachtung und die
native Gegenprobe begründen den Fix. Downloadhashes stehen in `sources.json`.
Es entstehen drei Farbuniforms; keine zusätzlichen Sampling- oder Cloudschleifen.
Der korrigierte Himmel beeinflusst erwartungsgemäß auch seinen Radiance-Cubemap;
Reflexions-/Materialabnahme nach Integration bleibt gemeinsam mit R32-08/09.

**Native Abnahme dieses engen Fixes:**
[Run 36983041310](https://github.com/MajorDragonfly/voxelverse/actions/runs/36983041310)
ist vollständig grün: drei direkte Tests, Quellen-/Import-/Artprüfungen und
je 20 neue Bilder in echtem GL bzw. Vulkan Forward+. QA-Commit
`b77334e8806347594c9f773a7f53c8815ca4da71`, Tree
`6577d7f6d38a644d6a1f5f4685ccd3a4641b9a81`; Fach-Codecommit
`29257564658927d42b7a3295b9f6f1392d517f54`, Tree
`344e8d21c3fb80b797ee6c2b89be768ffe54f147`. Der QA-Tree ergänzt nur den
isolierten Workflow; ausführbare Fachdateien sind bytegleich.

Die 40 unveränderten Basisbilder kommen aus dem ebenfalls grünen
[Run 36976482545](https://github.com/MajorDragonfly/voxelverse/actions/runs/36976482545).
Seine zusätzlichen 40 damaligen Fachbilder bilden die erhaltene Negativkontrolle
ohne Produktionsänderung. Insgesamt enthält der finale Vergleich 80 native
Bilder und 40 Vorher/Nachher-Paare, ohne Abweichung der protokollierten
Kamera-/Uhr-/Licht-/Preset-/Materialbedingungen. Start-/Endmanifeste sind stabil,
es wurde kein fremder Godot-Prozess beobachtet. Die unabhängigen CI-Jobs benutzen
Mesa 25.2.8 / llvmpipe LLVM 20.1.2, Vulkan 1.4.318 für Forward+.

Elf unskalierte Tafeln wurden visuell geprüft. Die native Bildregion wird nur
verlustfrei eingefügt; Titel stehen außerhalb der Originalbilder:

| Vergleich | Bilder |
| --- | --- |
| Nachthimmel vorher/nachher | [Compatibility](comparison/gl-night-sky-before-after.png), [Forward+](comparison/forward-night-sky-before-after.png) |
| Waldschatten, Tag/Nacht | [Renderervergleich](comparison/forest-renderers.png) |
| Heller Schneehang, Tag/Nacht | [Renderervergleich](comparison/snow-renderers.png) |
| Wasser und Ufer, Tag/Nacht | [Renderervergleich](comparison/water-renderers.png) |
| Kreaturen und Horizont, Tag/Nacht | [Heimat](comparison/creature-horizon-renderers.png), [Nahansicht](comparison/creature-close-renderers.png) |
| Komponenten im Wald | [Compatibility](comparison/gl-forest-components.png), [Forward+](comparison/forward-forest-components.png) |
| Komponenten im Schnee | [Compatibility](comparison/gl-snow-components.png), [Forward+](comparison/forward-snow-components.png) |

## Methode

`tools/review_r32_06_campaign_light.py` startet Godot 4.6.3 mit isolierten
Nutzerdaten und dem öffentlichen `SessionFlow` in `main/spherical_campaign.tscn`.
Seed 15838, Preset „Ausgewogen“ (1), 960×540, FOV 70°, Near 0,2 m/Far 30000 m.
Der Referenzspielstand und seine ausgelagerten immutable Regionsblobs werden
als Originaltext weitergereicht, über ihre SHA-256 geprüft und vom vorhandenen
SaveService validiert. Ein Snapshot-Export ohne Bilder ist ausdrücklich kein
Rendernachweis. Es gibt keine Ersatzgeometrie oder geänderten Pigmente.

Die Orte werden deterministisch auf demselben generierten Planeten ausgewählt:
Waldschatten, Schneehang, Wasser, Heimatbereich/Horizont und Kreatur-Nahansicht.
Kanonische Adressen, Kameratransformationen, Materialien und Klima sind im
Messbericht festgehalten. Flora und Fernszenerie müssen vollständig veröffentlicht
sein, bevor eine Aufnahme beginnt. Die Simulation steht während der Messung;
nur die normalen Streamingbesitzer laufen bei der Vorbereitung.

Tag und Nacht nutzen die Uhrzeit der maximalen/minimalen lokalen Sonnenhöhe.
Der Produktionspfad leitet Sonnenrichtung und Himmel aus dieser Uhr ab. Der
Helfer überschreibt weder die Sonnenbasis noch den Tageslichtfaktor. Die gleiche
Referenz wird zwischen Compatibility und Forward+ sowie Basis/Fachstand benutzt.
Rendererabhängige Sonnenenergie, SSAO, Bloom und volumetrischer Nebel sind
vorhandene Produktionsunterschiede und werden im JSON ausgewiesen.

Pro Produktionsbild: vier Aufwärmzeichnungen, sechs beibehaltene
`RenderingServer.force_draw(false)`-Wallzeiten; Bildrücklesen separat. Pro
Komponentenbild: vier Aufwärmzeichnungen, zwei Kostenproben. Das sind pausierte
Zeichenkosten, keine Frameintervalle des laufenden Spiels. Prozessguard 600 s,
Kampagnenladeguard 150 s und Streamingguard 90 s werden nicht gelockert.
Der Helfer beobachtet andere Godot-Prozesse und hält einen exklusiven Host-Lock.
R32-06 benutzt wegen des belegten gemeinsamen Host-Slots eigene CI-Rechner.

## Komponenten statt pauschaler Belichtung

Bei festem Tag/Kamera/Preset werden Sonne aus, Ambiente aus, halbe Belichtung,
Weißpunkt 1 und ein unbeleuchteter Materialpass aufgenommen. Der letzte Pass
nutzt dieselbe Geometrie und dieselben Materialwerte, lineares Tonemapping,
Belichtung 1 sowie ausgeschaltete Bildanpassung/Fog/Glow. Er ist eine
Darstellungsdiagnose; Materialshader, Reflexionen und gemischte Bildschirmregionen
sind keine isolierte rohe Albedo- oder Luxmessung. Die Effekte dürfen wegen des
nichtlinearen Tonemappings nicht additiv als Prozentanteile summiert werden.

Der ursprüngliche untere Bildhälftenraster enthält die HUD-Anzeige. Die zusätzliche
Auswertung verwendet das feste HUD-freie Rechteck `(96, 270, 680, 410)` bei
960×540. Beide Messungen sind sRGB-Anzeigeluminanz mit Gewichten
0,2126/0,7152/0,0722. „Weiß“ bedeutet alle Kanäle >0,98; „schwarz“ bedeutet
Luminanz <0,015. Sie beschreiben ein gemischtes Bild und ersetzen die visuelle
Kontrolle der Schattenkanten, Schnee-/Steinstufen, Ufer und Kreaturfarben nicht.

## Reproduktion und gemeinsame Anschlüsse

Nach dem regulären Import auf einem freien Messrechner:

```bash
python3 tools/review_r32_06_campaign_light.py --godot /pfad/zu/godot \
  --renderer gl_compatibility --replay docs/evidence/r32-06/reference.json \
  --component-views forest snow --output /neuer/pfad/gl
python3 tools/review_r32_06_campaign_light.py --godot /pfad/zu/godot \
  --renderer forward_plus --replay docs/evidence/r32-06/reference.json \
  --component-views forest snow --output /neuer/pfad/forward
```

Unter Linux braucht ein nativer Lauf eine Anzeige; die CI verwendet `xvfb-run`.
Der Standard-Lock entspricht dem R32-Host-Lock. Ein eigener Lock darf nur auf
einem tatsächlich unabhängigen Messrechner verwendet werden. Die Python-Hülle
erzwingt Software-Rendering; ein Ziel-PC-Nachweis muss den regulären Spielpfad
und die tatsächliche Hardware getrennt messen.

`tools/review_r32_06_light_compare.py --gl GL_ARTEFAKT --forward FWD_ARTEFAKT
--output NEUES_VERZEICHNIS` prüft Bildhashes, Messbedingungen und Quellenstatus,
berechnet Vorher-/Nachher-Differenzen und erstellt die unskalierten Bildtafeln.
Es benötigt Pillow und NumPy. Bildunterschiede werden berichtet und nicht
automatisch als Lichtverbesserung ausgelegt.

`R32-01-light-fixture.patch` ist ausschließlich ein Anschlussvorschlag an R32-01
für den älteren gemeinsamen `review_light_balance.gd`: Nach der Kampagnenuhr-
Integration überschreibt `update_view` dessen manuell gesetzte Sonne. Der Patch
legt die Fixture-Basis rückwärts aus der Fixture-Uhrzeit fest. `git apply --check`
ist geprüft; seine native Fixture-Abnahme gehört zum Anschluss durch R32-01.
Die tatsächliche Kampagnenaufnahme benutzt diesen Patch nicht.

Der isolierte CI-Workflow liegt nur auf `agent/r32-06-light-evidence-20261002`;
ein Owner-Patch wird R32-01 mitgegeben. Keine bestehende Workflow-, Registry-,
Status- oder Grafikseiten-Datei wird auf diesem Fachbranch geändert.
`final/used-sky-fix-workflow.yml` bewahrt exakt den ausgeführten Fix-Workflow;
dieser benutzt die bereits gemessene feste Basis. Der Owner-Patch erweitert ihn
um einen frischen Basislauf mit derselben eingecheckten Referenz. Er ist mit
`git apply --check` geprüft, aber diese zusammengesetzte Workflowfassung wurde
nicht zusätzlich ausgeführt. Trigger und Integrationsquelle bei Übernahme durch
R32-01 festlegen, danach auf dem gemeinsamen Tree prüfen. Kein neuer Registry-
Eintrag ist erforderlich. Die Grafikregler-/Persistenztests sind grün; Änderungen
an der Grafikseite oder ein gemeinsamer Regleranschluss gehen ausschließlich
über R32-15.

## Ursprüngliche fehlgeschlagene Läufe

[Run 36972326006](https://github.com/MajorDragonfly/voxelverse/actions/runs/36972326006):
Die drei direkten Tests und Quellen-/Import-/Artprüfungen bestanden. Der erste
native Compatibility-Basislauf bestand mit 28 Bildern in 508,25 s. Der Replay
scheiterte am Prüfhelfer: `create_slot` öffnet eine Session, der öffentliche
Ladeweg benötigt den Titelzustand. Dieser Zustand wurde im Helfer korrigiert.

[Run 36973988325](https://github.com/MajorDragonfly/voxelverse/actions/runs/36973988325):
Die direkten Tests bestanden in beiden Jobs. Beide Replays lehnten den
unvollständig übertragenen Spielstand ab. Die erste Vermutung eines
Präzisionsproblems wurde durch die zusätzliche Diagnose korrigiert:
Auch mit Originalbytes fehlten die separat gespeicherten Regionsblobs.

[Run 36974879426](https://github.com/MajorDragonfly/voxelverse/actions/runs/36974879426):
Der Compatibility-Referenzlauf bestand mit 20 Bildern in 341,24 s. Der Forward+
Replay meldete explizit `Regionsdatei fehlt` für die Root-Adresse
`621ffe88fe4d9264357a99dd5d52b1138490ab18e618d9a589a5992ddab34569`.
Der neue Helfer bewahrt Save und Regionsdateien bytegenau, validiert vor/nach
dem Schreiben und hält den Kampagnen-SaveService unverändert.
Die roten Gesamtläufe werden nicht als erfolgreiche Renderer-Abnahme gezählt.
Originalartefakte und SHA-256 stehen in `sources.json`.
