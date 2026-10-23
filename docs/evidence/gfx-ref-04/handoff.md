## GFX-REF-04

Basis: `148ba0bb578e9a01db501444fd11823fa09e8212`
Branch: `agent/graphics-reference-pass-04-20261023`
Liefercommit: `a6fe4a600552a74335242689c542a7d622b48cc4`
Tree: `062f512579ac40e852ed617006edde879f5fea35`
Arbeitsstand: sauber (lokal beobachtet).

### Ergebnis

Ruhigere Blatt-/Strauchpigmente, warmes direktes und kühles Himmelsfülllicht sowie lesbarerer Tiefendunst im regulären Kugelspiel. Gemeinsame Paletten-/Facetöne auch im gebündelten Fern-HLOD. Vier geänderte Dateien; keine Modell-, Platzierungs-, ID-, Save- oder Budgetänderung.

### Abhängigkeiten und gemeinsame Anschlüsse

Baut auf dem integrierten GFX-REF-03 (#292) und main148ba0bb auf. Direkte Verbraucher: planet_foliage.gdshader, surface_scenery.gdshader und planet_cluster.gdshader. Gemeinsame Funktion aus planet_surface_detail.gdshaderinc; Import-/Clusterbuilder und geschützte Diagnosebesitzerdateien bleiben unverändert.

### Prüfung

Aktueller Sourcehead a6fe4a600552a74335242689c542a7d622b48cc4 / Tree062f512579ac40e852ed617006edde879f5fea35. CI-Merge d0ad13200129f5c0cde17107b1798faf417a109d hat exakt denselben Tree. Alle298 registrierten Quelltests tatsächlich genau einmal in8disjunkten Gruppen, sämtliche Raw-Checkloghashes und vollständige saubere Source-Manifeste geprüft; Runtime27/27 inklusive26Raw-Loghashes. Alle vier aktuellen offiziellen Gates (Godot/Desktop/Environment/Dashboard, App15368) grün. Aktuelle native reguläre GL342.354s und Forward+509.549s,32Originalbilder, strenge8Restore- und4Nacht-Lichtkontrollen positiv; originale600s-Grenze erhalten. Vollständige Körper-/Kamera-/Clock-/Wetter-/Palette-/Dunst-/Pigmentbedingungen exakt zwischen Renderern; alle vier Source-Manifeste bytegleich. Godot4.6.3, lokales SoftwareMesa25.2.8, LP_NUM_THREADS2. Befehle/Hashes in den unveränderten Native-ZIPs; SourceSHA2565fe23854e06a05a11a274873f8913b9db357b243c87e27994ec3288fe398bcc4,10018Dateien/916018890Bytes. Bestehender nativer Clustervergleich0.00276721<unveränderter0.004-Grenze und Drawcalls10→4 positiv; aktueller offizieller Environment-GL-Fall ebenfalls positiv. Echter Sunset-Negativfall vor Fix2Fehler, nach Fixpositiv. Originalnegative und Vorgängerbilder klar getrennt archiviert.
Dieser Generator hat keine Spielprüfung ausgeführt und keinen Prüferfolg abgeleitet.

### Offen

Linux und Windows jeweils42/42 einschließlich jeweils41Original-Loghashes und3Releaseprobes positiv verifiziert; tatsächlicher main-Merge 0cc3e2c34037990535672b626601aac535ab2467 mit exakt getestetem Tree062f512579ac40e852ed617006edde879f5fea35 und beiden erwarteten Eltern verifiziert. Sichtprüfung auf Lars' Referenz-PC sowie Hardware-FPS bleiben separat offen. Software-/pausierte Draw-Daten ersetzen keine Hardwarefreigabe. Diese Etappe erreicht noch nicht den gesamten Referenzlook; Terrainkomposition und Vegetationsdichte wurden hier nicht geändert.

<details><summary>Tatsächlicher Dateiumfang</summary>

```text
assets/catalog/planet_cluster.gdshader           |  4 +--
 assets/catalog/planet_surface_detail.gdshaderinc | 18 ++++++++++-
 tests/campaign_atmosphere_test.gd                | 41 ++++++++++++++++++++++++
 world/visuals/atmosphere/campaign_atmosphere.gd  | 33 +++++++++++++------
 4 files changed, 83 insertions(+), 13 deletions(-)

M	assets/catalog/planet_cluster.gdshader
M	assets/catalog/planet_surface_detail.gdshaderinc
M	tests/campaign_atmosphere_test.gd
M	world/visuals/atmosphere/campaign_atmosphere.gd
```

</details>

Bei Veröffentlichung über einen anderen Git-Commit die Tree-Gleichheit belegen und beide IDs nennen.
