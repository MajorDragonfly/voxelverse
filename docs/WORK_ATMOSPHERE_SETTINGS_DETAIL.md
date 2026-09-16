# ATMOSPHERE-SETTINGS-DETAIL

Basis: Spieltest #125, `d57b1ef385728728b132518a1ea05683888dcae0`.
Eigener Branch: `agent/atmosphere-settings-detail-20260916`.

## Bedienung

Hauptmenü → Einstellungen → **Grafik** oder im Spiel **Esc → Einstellungen → Grafik**.
Anzeige, Steuerung, Sprache und Grafik liegen im gemeinsamen Dialog;
**Anzeige → Ton und Musik …** öffnet sämtliche Audioeinstellungen.
F8 bleibt ein optionaler Direktzugriff, kein erforderlicher Spielschritt.
18 Einzelwerte in sieben Gruppen:

| Bereich | Regler |
|---|---|
| Wolken | Anzeigen, Detailqualität |
| Entfernungsdunst | Stärke 0–2 |
| Volumetrischer Nebel/Lichtstrahlen | Anzeigen, Qualität, Stärke 0–2 |
| Sonnenschatten | Anzeigen, Qualität, Weichheit 0–2, Reichweite 50–500 m |
| Kontaktschatten/SSAO | Anzeigen, Qualität, Stärke 0–2 |
| Bloom/Leuchteffekte | Anzeigen, Stärke 0–0,8 |
| Bild | Belichtung 0,5–1,5, Kontrast 0,75–1,25, Sättigung 0–1,5 |

Basis/Atmosphärisch/Cineastisch setzen jeweils einen vollständigen, reproduzierbaren
Wertesatz. Eine Einzeländerung zeigt **Benutzerdefiniert**. Übernehmen aktiviert und
speichert; Zurück/Esc verwerfen den Entwurf. **Grafikstandard wiederherstellen**
setzt den Entwurf auf Atmosphärisch, ebenfalls erst nach Übernehmen wirksam.
Schieberegler, Zahleneingabe und Tastatur sind verbunden. Fokus scrollt auch nach
einem verzögerten Containerlayout in den sichtbaren Bereich. DE/EN sind vorhanden.

Nicht verfügbare Effekte werden im jeweiligen Abschnitt erklärt und deaktiviert;
gespeicherte Wünsche bleiben erhalten. Wie beim bisherigen Atmosphärenpreset sind
Volumennebel, SSAO und Bloom in diesem Controller nur für Forward+ aktiviert.
Schattenweichheit ist im Kompatibilitätsmodus deaktiviert.

## Anschlüsse und Grenzen

- `DisplaySettings` bleibt Eigentümer der geräteweiten Einstellungen. Neue
  `graphics`-Sektion (Schema 1) in derselben `display_settings.cfg`; kein Spielstandfeld.
  Alte Presetdateien werden übernommen, numerische Einzelwerte begrenzt, ungültige
  Werte ersetzt. Zukunftsversionen bleiben vor Überschreiben geschützt. Speichern
  erfolgt über temporäre Datei und atomare Umbenennung. Bei Schreibfehler bleibt
  die letzte Datei bestehen; bereits angewandte Anzeige bleibt für diese Sitzung aktiv,
  der gemeinsame Dialog meldet den Fehler wie bisher.
- `graphics_preferences.gd` definiert Werte und Grenzen. Die Anzeige-Autoload
  setzt globale Godot-Qualität (Schattenatlas/Filter, SSAO-Abtastung, Nebelvolumen).
  Szenen erzeugen keine zweite globale Einstellungsinstanz.
- `CampaignAtmosphere` liest Werte beim Aufbau und übernimmt Änderungen auch bei
  Pause. Wolken werden im Shader wirklich übersprungen, Dunst-/Nebelstärken bleiben
  Multiplikatoren der bestehenden planetaren Darstellung.
- `UnderwaterView` behält die Kamera und die Wasser-Sichtregeln. Belichtung/Farbe
  werden auch während des Tauchens aktualisiert; Auftauchen zeigt den aktuellen Himmel.
- Wettermodell, Klima, Niederschlagsereignisse, Terrain, Ressourcen und SaveService
  werden nicht verändert. Keine neue Wetter-/Atmosphärenarchitektur.

Gemeinsame Integrationsstellen: `core/display_settings.gd`, Atmosphärencontroller/
Himmelshader, Unterwasseransicht, Sprachkatalog und `terrain_art`-Testregistrierung.
Zentrale Status-/Roadmap-Häkchen aktualisiert die Integration nach Übernahme.

## Prüfungen

`graphics_settings_test` ist genau einmal unter `terrain_art` registriert. Er prüft
echte Maus-/Tastatureingaben, Entwurf/Übernehmen/Reset/Abbruch, Presetwechsel,
Legacy-/ungültige-/Zukunftsdaten, absichtlichen Schreibfehler, Unterwasserwechsel,
800×600/1280×720/1920×1080 mit 130 % UI-Skalierung in DE/EN, echte Kampagne mit
Speichern/Laden und Planetenwechsel sowie eigene Werte in einem frischen Godot-Prozess.

```sh
python3 tools/validate_godot.py --godot GODOT --tests graphics_settings_test campaign_atmosphere_test underwater_view_test localization_test weather_runtime_test --skip-main --output OUT
xvfb-run -a python3 tools/review_graphics_settings.py --godot GODOT --renderer forward_plus --output OUT_RENDER
```

Die Grafikprüfung läuft auch mit `gl_compatibility` im Workflow
`Graphics settings review`. Sie erzeugt je Renderer 15 echte Aufnahmen: Vorher/Nachher
in einer festen Voxelszene, Unterwasser sowie Anfang/Ende des Menüs in den sechs
Sprach-/Größenkombinationen. Sie führt die Bedien-/Neustartprüfungen erneut aus;
der Kampagnen-/Reiseteil gehört zum separaten Headless-Fachlauf.

Die ersten Prüfläufe fanden einen Fehler im Testaufbau (Slot vor öffentlichem Laden
noch aktiv) und das echte verzögerte Scroll-/Fokusproblem. Beides wurde korrigiert;
die ursprünglichen Protokolle bleiben im Nachweis erhalten. Die genaue Revision,
Befehle und Ergebnisse stehen in `docs/evidence/atmosphere-settings/README.md`.

Keine Ziel-PC-/60-FPS- oder Windows-Freigabe. Die native Szene prüft Darstellung
und Bedienung, nicht die Performance einer vollständigen Kampagne.

Verwendete Engine-API: [Godot 4.6 RenderingServer](https://docs.godotengine.org/en/4.6/classes/class_renderingserver.html)
und [Environment](https://docs.godotengine.org/en/4.6/classes/class_environment.html).
