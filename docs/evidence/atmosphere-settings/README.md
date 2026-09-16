# Fachnachweis · ATMOSPHERE-SETTINGS-DETAIL

Godot `4.6.3.stable.official.7d41c59c4`, Linux/headless, isolierte Nutzerdaten.
Keine Windows-, GPU-/Ziel-PC-FPS- oder vollständige Integrationsfreigabe.

## Abschließender Fachlauf

Fünf Fachtests plus Quell-/Sprachgate erfolgreich auf **sauberem, unverändertem**
lokalem Quellcommit `337c33f597419345578ac5e421295f3c4cc18379`:

- `graphics_settings_test`: 55 Bedingungen, zusätzlich frischer Prozess;
  reale Maus/Tastatur, Presets/Entwurf/Reset, Speicherfehler/Legacy/Zukunftsversion,
  Unterwasser, sechs Layout-/Sprachkombinationen, echte Kampagne/Laden/Planetenreise.
- `campaign_atmosphere_test`
- `underwater_view_test`
- `localization_test`
- `weather_runtime_test`

[Exakter Befehl, Quellfingerabdruck und unveränderte Prozessresultate](final/results.json).
Import war bereits unter derselben Engine im selben Checkout erfolgreich; der
abschließende Lauf nutzt `--skip-import`. Die importpflichtigen Ressourcen sind
seit dem letzten erfolgreichen Import unverändert. `details-focus-fixed/import.log`
enthält diesen Import; die anschließend korrigierte Fokuslogik ist GDScript.

Veröffentlichung über den verbundenen GitHub-Zugang: Der Quellcommit erhält eine
neue Commit-ID, sein vollständiger Tree ist **byteidentisch**:
`a1cc86b4d05e2e6b2eca47ba97d7ba4d976fff91` →
`a80534483af3fe55f9b04331eb6d461579a33879`.
Siehe [Zuordnung](publication.json). Dieser Nachweisnachtrag ändert nur Dokumentation.

## Frühere Läufe und gefundene Fehler

Alle folgenden Ergebnisse stammen aus dem jeweils im `results.json` erfassten
Arbeitsstand; sie werden nicht als weitere Läufe auf dem Abschlusscommit ausgegeben.

| Verzeichnis | Ergebnis und Einordnung |
|---|---|
| `initial` | Import/Art-/Quellgate sowie Atmosphäre, Unterwasser und echter Frontend-Test bestanden, vor letztem Fokus-/Konfigurationsschutz |
| `details-initial` | Neuer Test fand fehlenden Scrollfokus; zusätzlich falscher Testaufbau mit bereits aktivem Slot vor öffentlichem Laden |
| `details-corrected` | Kampagne/Reise/Neustart bestanden; Scrollfokus noch fehlerhaft |
| `input-diagnostic`, `focus-diagnostic`, `details-focus-fixed` | Begrenzte Reproduktionen: Fokus vorhanden, Control unterhalb des sichtbaren Bereichs; erste Deferred-Lösung zu früh |
| `scroll-diagnostic` | Direkter späterer Scrollaufruf bestätigt Ursache; kein finaler Produktnachweis |
| `details-final-candidate` | Produktkorrektur nach zwei Layoutframes; vollständiger neuer Test bestanden |
| `final` | Abschließender sauberer Fachlauf, siehe oben |

Die absichtlichen Fehlerschreibversuche erzeugen erwartete Warnungen. Unveränderte
Originalprotokolle und Resultate sind beigelegt; kein Fehllauf wurde umetikettiert.

## Native Darstellung

Der dedizierte [Graphics-settings-Workflow](https://github.com/MajorDragonfly/voxelverse/actions/workflows/graphics-settings-validate.yml)
führt den reproduzierbaren Grafikrunner mit Forward+ und Compatibility aus.
Beide Renderer bestehen den [nativen Lauf 35068063587](https://github.com/MajorDragonfly/voxelverse/actions/runs/35068063587)
auf PR-Mergecommit `e003c4972cc519cac878bba2f5aea1c8c7f80d3e`, Tree
`a80534483af3fe55f9b04331eb6d461579a33879` (identisch zum Fachlauf).
Jeweils sauberer, unveränderter Quellstand, alle 15 Bilddateien erzeugt und
Bedien-/Neustartprüfungen erfolgreich. Originale Joblogs sowie die daraus
unverändert extrahierten Ergebnisobjekte liegen unter `native/`.

[Forward+-Bilder](https://github.com/MajorDragonfly/voxelverse/actions/runs/35068063587/artifacts/10434674457) ·
[Compatibility-Bilder](https://github.com/MajorDragonfly/voxelverse/actions/runs/35068063587/artifacts/10435226433).
Die signierten Bilddownloads lieferten in dieser Arbeitsumgebung HTTP 403
(`error code: 1010`); deshalb wird keine zusätzliche Sichtprüfung durch den
Assistenten behauptet. Layout/Eingaben und Bildausgabe sind automatisiert nativ
geprüft. Die optische Abnahme am Ziel-PC bleibt offen.

Der Grafikrunner prüft vor/nach dem Lauf einen sauberen, unveränderten Commit und
Tree. Je Renderer: 15 Aufnahmen, zwei Sprachen, drei Größen bei 130 %, Eingabe,
Neustart, Darstellung der echten Atmosphären-/Unterwassercontroller in einer festen
Voxelszene. Kampagnenreise wird separat im Fachlauf geprüft.
