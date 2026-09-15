# Planetenwetter – WEATHER-01 bis WEATHER-05

Auftrag von Lars, 15.09.2026: wechselndes Wetter auf Kugelplaneten, ein friedlicher,
erdähnlicher Startplanet und später gefährliche Extremplaneten mit Feuer- und
Sandstürmen. Keine Veränderung der laufenden ARCH-13/-17/-24/-26/-27-Pakete.

## WEATHER-01 – mildes Wetter in der Kugelkampagne

**Fachlieferung im [Entwurfs-PR #118](https://github.com/MajorDragonfly/voxelverse/pull/118), noch nicht in main integriert.** Basis:
`1d6573d9551c3f24bf1dd6fa64e5c301583a26c8` aus
`agent/integration-vegetation-nest-20260915`.

- Grundtakt vor regionaler Anpassung: Ein neues Spiel beginnt mit leichtem
  Wolkenbesatz und schwachem Wind.
  Nach 3,5–5 Kampagnenminuten zieht im Grundtakt Bewölkung auf, nach 7–10 Minuten folgt der
  erste Niesel-/Regenschauer. Danach wechseln klare, windige, bedeckte und nasse
  Fronten deterministisch. Übergänge dauern 35 Sekunden; Restnässe klingt langsamer ab.
- Der Grundtakt liefert 1,2–4,8 m/s Wind; Regen höchstens 0,65 der Darstellungsintensität.
  Kein Blitz, Feuer, Sandsturm, Temperaturstress oder Wetterschaden. In dieser
  Lieferung verwenden **alle** regulären Kampagnenkörper dieses milde Profil; WEATHER-02A passt die Niederschlagsart an die örtliche Kälte an.
  Die vorhandene Flora-/Farbklimazahl aktiviert keine Gefahren.
- Voxelwolken und schräg fallender Regen folgen der lokalen radialen Ausrichtung
  und der aktiven Kamera; dadurch auch mit Stammeskamera und Floating Origin nutzbar.
  Unter Wasser werden beide ausgeblendet. Ein Dach über der Kamera unterdrückt
  Regen; Boden-/Dachproben begrenzen fallende Tropfen im Nahbereich.
- Ein zusätzlicher `Weather`-Knoten in `main/spherical_campaign.tscn` ist der
  einzige Anschluss im Szenenhost. `spherical_campaign.gd`, Terrain, Shader,
  Welt-/Kamera-Environment, Sonne und Audio bleiben bei ihren vorhandenen Besitzern.

## WEATHER-02A – regionale Fronten, Schnee und Windböen

**Vertiefung auf Nutzerfreigabe vom 15.09.2026.** Der vorhandene Temperatur-/
Feuchtewert der Kugeloberfläche steuert die örtliche Niederschlagsstärke und -art.
Feuchte Gebiete bekommen Schauer; sehr trockene Regionen bleiben niederschlagsarm
oder trocken. In kalten Regionen fällt sanfter Schnee, im Übergang Schneeregen.
Alle Varianten bleiben ohne Wetterschaden, Feuer- oder Sandsturm.

Ein bewegtes dreidimensionales Feld mit etwa 3,2 km Rasterweite verschiebt
Wetterfronten regional um bis zu 95 Sekunden und formt Wolken-/Schauerbänder.
Es wird in körperfesten Double-Koordinaten auf Meereshöhe ausgewertet, nicht in
lokalen Welt-X/Z- oder flächenweisen Cube-Rastern. Damit bleiben Übergänge über
Cube-Kanten und Pole stetig; die Kamerahöhe verschiebt keine Front. Temperatur
und Feuchte kommen weiter aus dem vorhandenen Landschaftsgenerator.

Der Wind wird körperfest auf die lokale Tangentialebene projiziert. Sanfte Böen
variieren ihn kontinuierlich (höchstens knapp 5,4 m/s); natürliche ruhige Punkte
sind erlaubt. Die Darstellung nutzt einen analytischen Driftversatz, damit
wechselnde Böen nach langen Spielsitzungen keine Wolken-/Partikelsprünge erzeugen.
Weiße, langsam taumelnde Voxel-Schneeflocken teilen sich den bestehenden
384-Instanzen-Pool mit Regen. Die Zahl der Zeichenbatches wächst dadurch nicht.
Bei Kameratausch oder mehr als 3 m Entfernung von der letzten Bodenprobe werden
alte Dach-/Bodenwerte verworfen, bis der begrenzte Prüfzyklus neue Werte liefert.

Der Leseanschluss `forecast()` liefert drei lokale Prognosen für +60/+120/+180
Kampagnensekunden, jeweils mit Regen-/Schneestärke und Wind. Es ist eine Abfrage
am aktuellen Ort mit dessen gegenwärtiger Temperatur/Feuchte, keine neue Uhr
oder Simulation. Eine spätere UI kann diese Werte darstellen. Die Diagnose-
Vorschau überschreibt die Anzeige, nicht die normale Prognose.

Atmosphärenlose Deskriptoren unterdrücken Wolken, Wind und Niederschlag auch in
der Diagnosevorschau. Der aktuelle Kampagnengenerator liefert noch durchgehend
`temperate`; die Auswahl echter Vakuum-/Extremkörper und die dauerhafte
Herkunftsplanet-Kennung bleiben WEATHER-02. Es wird keine neue Save-Struktur
angelegt und kein Startplanet anhand von Listenposition oder Seed erraten.

## Daten- und Darstellungsvertrag

`world/weather/weather_model.gd` und `regional_weather.gd` sind reine Ableitungen. Eingaben sind stabile
`body_id`, Planetenseed und die bereits gespeicherte `campaign.elapsed_seconds`.
Keine neue Save-Datei, kein Timer mit Echtzeitdatum, keine Offlineproduktion,
keine Migration und kein zweiter autoritativer Kampagnenzustand. Laden und
Wiederbesuch rekonstruieren das Wetter zur gemeinsamen Spielzeit; Abwesenheit
bei weiterlaufender Kampagne darf somit eine andere Front ergeben. Pause,
Geschwindigkeit null, Menü und geschlossenes Spiel erzeugen keine zusätzliche Zeit.

Die Gruppe `campaign_weather` enthält genau den aktiven Szenenbesitzer.
`snapshot()` liefert eine Kopie; `weather_changed(snapshot)` liefert beim
Frontwechsel und höchstens etwa viermal pro Sekunde fortlaufende Werte. Das
Signal ist ein Darstellungsupdate, kein einmaliges Schadens-/Belohnungsereignis.
Während des Ladens ist der Snapshot leer; Verbraucher müssen leere/fehlende
Besitzer akzeptieren und sich nach Szenenwechsel neu binden.

| Feld | Bedeutung / Einheit |
|---|---|
| `schema`, `climate_id` | Darstellungsvertrag 1, aktuell `earth_temperate` |
| `body_id`, `seed`, `elapsed_seconds` | Körperbindung und gespeicherte Kampagnenzeit |
| `condition`, `previous_condition`, `transition` | Zielzustand, vorige Front und weicher Fortschritt 0–1 |
| `cloud_cover`, `precipitation`, `wetness` | Normierte Bewölkung, gesamte Niederschlagsstärke, abklingende Oberflächennässe |
| `wind_mps`, `wind_bearing` | Windgeschwindigkeit und Winkel in Radiant im lokalen `Cube.frame(up)`; Richtung `frame.x*cos(bearing) + frame.z*sin(bearing)` |
| `visibility_m` | Sichtweitenwunsch für den Rendering-Besitzer; WEATHER-01 schreibt keinen Nebelwert |
| `front_index`, `seconds_to_next_front` | Deterministische Frontnummer und Restzeit im örtlichen Grundtakt; konkrete Prognosen über `forecast()` |
| `hazard_kind`, `hazard_intensity` | Aktuell immer `none` / `0.0`; keine wirksame Schadensberechnung |
| `preview` | Nur lokale Startparameter-Vorschau; wird nicht gespeichert |
| `regional_schema`, `regional_seconds`, `region_strength` | Additiver Regionalvertrag 1, örtliche Frontzeit, Stärke des lokalen Wolkenbandes |
| `rain_intensity`, `snow_intensity`, `snow_fraction` | Regen-/Schneeanteile; beide Intensitäten zusammen ergeben `precipitation` |
| `wind_velocity`, `wind_offset`, `gust_strength` | Körperfester Windvektor in m/s, analytischer Versatz in lokalen Tangentialmetern, Böenstärke 0–1 |
| `temperature_factor`, `moisture_factor` | Gelesene normierte Landschaftswerte; keine Celsiuswerte |
| `atmosphere_present`, `sheltered`, `underwater` | Atmosphären-/Sichtkontext; keine autoritative Schadens- oder Schutzbewertung |

**Anschluss für Rendering/Shader:** `clouds_enabled = false` schaltet nur die
mitgelieferten Wolken ab, wenn der Rendering-Chat eigene Wolken übernimmt.
`precipitation_enabled` erlaubt ebenso die Übernahme der Regenvisualisierung.
Himmel-/Nebelverdichtung, Sonnenlicht, nasse Materialien und Vegetationsbewegung
können die oben genannten Werte lesen. Genau ein System komponiert dabei das
Environment; das Wettersystem schreibt weder Shader-Globals noch Kameraressourcen.
Audio kann Wind/Regen aus demselben Snapshot ableiten; wetterabhängiger Ton ist
noch offen und ersetzt keine bestehenden Wind-/Wasserklänge.

**Budget:** zwei MultiMeshes, 384 vorallozierte Regen-/Schneeinstanzen und 96 Wolkenblöcke;
keine einzelnen Tropfen-Nodes, Physikkörper oder zusätzlichen Schatten. Pro
Sekunde höchstens 52 Dach-/Bodenstrahlen bei Regen (5×5 Raster plus Kameradach,
2 Hz), dazu eine radiale Wasser-/Klimaprobe je Physiktick und zwei
konstante Feldabfragen je sichtbarem Frame. Die Renderübergabe hält zusätzlich
höchstens 384 Transform-/Farbwerte für Diagnose und Headless-Prüfung vor. Unbekannter Boden
unterdrückt Tropfen bis zur nächsten gültigen Probe. Rasterabstand 6 m,
Dachprüfhöhe 22 m: kleine Dachkanten und sehr hohe Höhlen sind noch keine präzise
Einzeltropfen-Kollisionssimulation. Wolken sind eine kameraumgebende lokale Darstellung. Ihre Wetterwerte stammen
aus dem regionalen Feld; sie sind keine einzeln gespeicherten Weltobjekte.

## Folgepakete und Grenzen

| Paket | Lieferung | Abnahme vor Freigabe |
|---|---|---|
| WEATHER-02 – planetare Klimazonen (teilweise: 02A geliefert) | **02A:** regionale Fronten, Regen/Schnee, Böen und Prognose. **Offen:** versionierte Klimaprofile pro stabiler Körper-ID; Herkunftsplanet dauerhaft identifizieren und mild schützen; atmosphärenlose, trockene, eisige, vulkanische Welten; Integration weiterer Klimatypen | Startplanet bleibt bei allen Seeds, Migration, Körperreise und Neustart ungefährlich; kein Regen im Vakuum; kein Wetterwechsel an Cube-Nähten; unbekannte Save-Version geschützt |
| WEATHER-03 – Extremstürme | Sandstürme mit Staub/Sichtverlust/Wind, Feuerstürme mit Hitze/Asche/Glut, danach Schneestürme; Ablauf Ruhe → Vorwarnung → Anstieg → Sturm → Abklingen | Keine Extremprofile auf dem Startplaneten; Sturm vor Eintritt erkennbar; passende Farbe/Partikel/Audio; keine blinkenden Vollbildblitze; klare räumliche Grenzen und begrenzte Last |
| WEATHER-04 – Schutz und Auswirkungen | Gemeinsamer Expositions-/Schutzvertrag für Kreaturen, Bewohner, Gebäude und Ausrüstung; Tiere suchen Deckung; Arbeit/Transport können pausieren; sichere Landestelle; keine pauschale Terrainzerstörung | Schaden/Verbrauch genau einmal über bestehende Besitzer; Dach/Höhle/Schiff schützen nachvollziehbar; Save während Vorwarnung/Sturm und A–B–A ohne doppelten Schaden oder gefangene Bewohner; Rückkehr/Erholung möglich |
| WEATHER-05 – Inszenierung und Abnahme | Shader für Nässe/Staub, Wolken-/Nebel-/Lichtkomposition, Wetterklänge, UI-Warnung DE/EN, Intensitäts-/Qualitätsregler, Ziel-PC-Balancing | Gemeinsamer Rendering-/Shader-/Audio-Stand, Unterwasser und Kameras geprüft; Windows-Spieltest und 1080p60 auf Ziel-PC; keine ungemessenen FPS-Versprechen |

`arid_extreme`, `volcanic_extreme` und `frozen_extreme` sind im lesbaren Katalog
reserviert und ausdrücklich `implemented: false`. Die Modellabfrage lehnt sie
ab. Das Vorhandensein eines Profilnamens ist keine fertige Sturmimplementierung.
Extremwetter folgt der sicheren Planetenreise und Schutzmechanik; spätere
Weltraumexpeditionen führen auf entsprechende Planeten. Es ist keine zusätzliche
Epoche und kein Pflicht-Hindernis auf der friedlichen Heimatwelt.

## Spieltest

Normal starten und in einem feuchten Gebiet ungefähr 6–12 Kampagnenminuten spielen; trockene Regionen können regenfrei bleiben. Für unmittelbare Sichtprüfung
kann der native Build mit `-- --weather-preview=rain` gestartet werden, zum
Beispiel `Voxelverse.exe -- --weather-preview=rain`. Erlaubte Vorschauen:
`clear`, `breeze`, `overcast`, `drizzle`, `rain`, `snow`. Schneevorschau: `Voxelverse.exe -- --weather-preview=snow`. Unbekannte oder extreme Namen
werden ignoriert. Die Vorschau endet beim Neustart ohne Parameter und verändert
weder Save noch Wetterzeit. Kamera nach oben drehen, freies Feld, Dach,
Wasserlinie, Pause und Stammeskamera prüfen.

Automatisierte Nachweise: Vertrag `weather` in
`tools/validation/contracts.json`; Wettermodell einschließlich frischem Prozess,
sechs Kugelrichtungen, Regen-/Bodenbegrenzung, Unterwasser-/Schutz-Unterdrückung,
Renderer-Unabhängigkeit und echte Kampagne mit Pause, Save/Load und Rebase.
WEATHER-02A ergänzt Kanten-/Poltests, regionale Vielfalt, feucht/trocken/kalt/Vakuum,
Böen nach langen Sitzungen, Prognosevergleich und einen weiteren frischen Prozess.
Die grafische Abnahme im nativen Windows-Build und Ziel-PC-Leistung bleiben offen.
