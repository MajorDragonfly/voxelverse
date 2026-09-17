# WEATHER-03-STORM-PREVIEW

Auftrag: nächstes freies Arbeitspaket nach Nutzerauftrag vom 16.09.2026.
Reservierung in Issue #137. Basis: `176d088d34324de14952bc7506fe9763a22cf4b0`.
Branch: `agent/weather03-storm-preview-20260916`.

## Ergebnis und Anschluss

- `StormPreview.apply(snapshot, kind)` ist eine reine Ableitung. Nur ausdrücklich
  geschaltete Vorschauen auf ungeschützten, passenden Körpern mit Atmosphäre
  erhalten Sturmfelder. Fehlende Schutzangaben werden konservativ abgelehnt.
- `Regional.preview` und `CampaignWeather.set_preview_condition` verbinden die
  Vorschau mit der echten Kampagne. Der Startparameter ist weiterhin
  `-- --weather-preview=<condition>`. Leerer/unbekannter Wert beendet die Auswahl.
- Sand (`arid`) und Asche (`volcanic`) besitzen einen körper- und seedgebundenen
  Ablauf aus Ruhe, 30 s Vorwarnung, Anstieg, Höhepunkt und Abklingen. Keine neue
  Uhr, kein Reroll bei Pause/Laden und kein Save-Feld. Der vorhandene
  `forecast()`-Anschluss liefert weiterhin ausschließlich das normale Wetter.
- `WeatherView` nutzt seine zwei vorhandenen MultiMeshes. Kleine farbige Partikel
  ersetzen im Vorschauzyklus Regen/Schnee. Keine zusätzlichen Physikkörper,
  Schatten, Partikel-Nodes oder Zeichenbatches. Das bestehende Boden-/Dachraster
  wird auch für Staub abgefragt. Unterwasser-/Dachunterdrückung bleibt wirksam.
- Eine eigene passive CanvasLayer zeigt DE/EN-Phasen und Vorwarncountdown. Sie
  folgt der vorhandenen HUD-Pausen-/Inspektionsregel und verschwindet beim
  Abschalten, ungültigem Kontext und Szenenabbau.
- Sichtweitenwunsch und Wolkendeckung gehen über den vorhandenen Snapshot an
  den Atmosphärenbesitzer. Dieser Fachbranch verändert weder Environment noch
  Shader, Audio, M4-Verhalten, Terrain oder planetare Profilvergabe.

Der Windwinkel wird vor der Böenskalierung berechnet. Das verhindert kleine
geschwindigkeitsabhängige Rundungsänderungen, die bei großem integriertem
Versatz sichtbare Sprünge verursachen könnten.

## Prüfung

Registrierung: Vertrag `weather` in `tools/validation/contracts.json`.

- `weather_storm_test`: beide Arten, alle fünf Phasen, Vorwarnung ohne Staub,
  Phasen-/Zyklusgrenzen nach 2.000 Zyklen, Intensitätsgrenzen, Eingabeschutz,
  unverändertes Normalmodell, A–B–A und exakte Rekonstruktion aller Phasen in
  einem frischen Godot-Prozess. Physische Bodenprobe, Partikelfarbe/-form,
  Poolbudget, Dach/Wasser sowie DE/EN-Warnung bei 800×600 und 1280×720,
  Pause, Inspektion und leerem Kontext.
- `weather_runtime_test`: echter Kampagnenbesitzer, geschützte Heimat,
  Luftlosigkeit, künstlich passende Diagnoseprofile auf dem besuchten fremden
  Körper, Vorwarnung, Pause, Höhepunkt, Save ohne Vorschaufelder, Abschalten,
  Rückkehr ins Vakuum und Heimreise. Dazu vorhandene Kamera-, Rebase- und
  Save/Load-Prüfungen. Die Testprofile aktivieren keine normalen Extremziele.
- Direkte Verbraucher: `weather_model_test`, `regional_weather_test`,
  `planet_climate_test`; bestehende milde Profile, Rand-/Polstetigkeit, Prognose
  und Schutz-/Persistenzvertrag bleiben geprüft.

Lokaler Befehl (Godot 4.6.3, isolierte Nutzerdaten, Ausgabe außerhalb des Repos):

```sh
python3 tools/validate_godot.py --godot /path/to/godot \
  --contracts weather --skip-main --skip-import --output /tmp/weather03-check
```

`--skip-import` setzt einen erfolgreichen Import genau dieses Ressourcenstands
voraus. Commit/Tree, konkrete Ergebnisse und CI-Verweise stehen im PR. Headless
belegt die eingereichten Transform-/Farbwerte und HUD-Geometrie, keine gerenderte
Sturmszene. Grafische Sichtprüfung im nativen Build und Ziel-PC-Leistung bleiben
offen; der reguläre Render-Gate ergänzt den vorhandenen Darstellungsweg.

## Verbleibender Umfang

Dies liefert die begrenzte Vorschau, nicht das gesamte Extremwetterpaket:
keine räumlichen Sturmgrenzen, Glut/Hitze, Blizzard, Wetterklänge, Schäden oder
M4-Schutzsuche. Reservierte Extremprofile bleiben `implemented: false`.
Reguläre Freigabe benötigt Schutz-/Reisemechanik und anschließende Spielabnahme.
