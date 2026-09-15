# Aktueller Projektstand

Stand: 15. September 2026, zweite Integrationsrunde. Kurzer Einstieg für neue Fachchats.

## Aktueller Spieltest-Kandidat

Dritte Runde vom 15. September: `agent/playtest-latest-20260915`, auf #110
aufbauend. Zwölf weitere feste Lieferungen aus #111–123 sind zusammengeführt;
#122 ist die nicht doppelt integrierte Alternative zu #120.
[Exakte Eingangsliste, gemeinsame Korrekturen und Bedienung](INTEGRATION_2026-09-15_PLAYTEST.md).

Neu enthalten: Tieremotionen/korrigierte Lider, Modellrevisionen und Schwanzformen,
Stammes-Testslot, Tierhaltungs-UI DE/EN, mehrere Arbeitsplätze, Lagertransporte,
Terrain-Cachepflege, Archivlebensdauer, Wetter und Atmosphäre mit Grafikpresets.
Vollsuite und native Builds werden über die CI dieses Kandidaten abgenommen.
Folgende Angaben zur zweiten Runde bleiben als historische Basis erhalten.

## Historische gemeinsame Basis der zweiten Runde

- `main` beim Abruf: `d378ca0ecd7f03429a5150df6358e0646ec06689`, Merge von #92.
- Neuer gemeinsamer Kandidat: `agent/integration-vegetation-nest-20260915`.
  Enthält die veröffentlichten PRs **#93–109** und die Ressourcen-/Anschlusskorrekturen.
  Veröffentlichter Quell-/Werkzeugstand `753a15d07d660df9a297baf4ed1cb9704dae2dab`,
  identischer Tree zum lokal geprüften `d1f92fec1a1c4945bff0dc1481ab0aeb3a5074ae`.
  [Integrationsbranch auf GitHub](https://github.com/MajorDragonfly/voxelverse/tree/agent/integration-vegetation-nest-20260915);
  Prüfung und Freigabe erfolgen über den zugehörigen Integrations-PR.
  [Zuordnung aller Quellcommits](evidence/integration-publication-20260915.json).
  Exakte Eingangsköpfe: [Integrationsbericht](INTEGRATION_2026-09-15_RESOURCES.md).
- Der Kandidat ist eine eigene Branchlieferung. `main` wird dadurch nicht umbenannt
  oder stillschweigend als bereits geprüft erklärt. Für neue Pakete den festen
  Quellcommit aus der aktuellen PR-Übergabe verwenden.
- Godot **4.6.3**, Forward+, Jolt; regulärer Start ausschließlich über
  `ui/frontend/main_menu.tscn` → `main/spherical_campaign.tscn`.

## Enthalten und offen

| Bereich | Gemeinsamer Kandidat | Nächste Grenze |
|---|---|---|
| Kugelkampagne | Heimat, Dorf, vier Nutztierspezies, Milch/Eier und Körperreise | Zusammenhängende Ziel-PC-Abnahme |
| Vegetation/Heimat | Sechs individuell erzeugte Beerenformen, Planeten-/Biompalette, modernes Zweignest; stabile Form beim Wiederbesuch | Optische Abnahme im nativen Build |
| Speicher | Globaler Aufbewahrungsbericht, archivierte Begegnungen und Labortierhistorie; beide Blobverzeichnisse | Laufende Schreiber und sichere spätere Bereinigung |
| Leistung | Schrittweise Terrain-/Kollisionspublikation, begrenzte Tier-Audiobeobachter; Ernte ohne Mesh-/Colliderneubau | Restliche Einzelaufrufe und Ziel-PC-Messung |
| Kreaturen | Separater Rüssel, aktive Kiefer/Scheren, Katze/Bär/Schwein; Werkstatt DE/EN | Gespeicherte Teilrevisionen und weitere Katalogwünsche |
| UI/Audio | Vitalwerte unter der Minimap, Scanner, Dorfaufträge/Berufe und Entdeckungsbuch DE/EN; weichere Schritte und Wasserklänge | Restliche Tierhaltungs-/Epochenkopie und Hörabnahme |
| Siedlungen | Zwei produktive eigene Orte, getrennte Vorräte/Aufträge und Nah-/Fernarbeit | Gleichartige Arbeitsplätze im selben Ort, Transporte zwischen Lagern |
| Raumfahrt | Modularer Schiffseditor mit Vorlagen, Vorschau, Symmetrie, Bibliothek und Undo | Instanz-/Kampagnenanschluss und spätere spielbare Flugschleife |
| Entwicklungsablauf | Fachtestplan aus lokalem Git-Diff; aktualisierte Folgepakete | Neue Pakete immer von diesem gemeinsamen Stand ableiten |

**Enthaltener Code ist nicht automatisch vollständig abgenommen.** Die genaue
lokale und CI-Prüfung steht in der [aktuellen Übergabe](INTEGRATION_2026-09-15_RESOURCES.md).
Keine Ableitung von Ziel-PC-FPS aus Headless-/CPU-Ansichten.

Vorstand #93–108: 179 Godot-Tests mit dokumentierten Korrekturen/Nachläufen, 24
Laufzeit-/Quellprüfungen und 101 Python-Tests erfolgreich (6 optional ausgelassen).
Linux vollständig vor der letzten Flächenkorrektur und anschließend am neu
exportierten PCK gezielt geprüft. Windows und native Grafikprüfung bleiben offen.
Nachtrag #109: 10 direkte Fach-/Anschlusstests sowie Import und Quellgates am
sauberen `d1f92fe` erfolgreich. Registry jetzt 180 Tests; kein neuer Voll-/Exportlauf
für diesen Nachtrag behauptet. [Nachweis](evidence/integration-journal-109/README.md).

## Referenzhardware

| Komponente | Ausstattung |
|---|---|
| CPU | AMD Ryzen 7 9800X3D |
| GPU | NVIDIA GeForce RTX 4070 Ti |
| RAM | 32 GB, 5200 MT/s |

Vorläufiges Ziel: 1920 × 1080 bei 60 FPS. Preset und Treiber beim Lauf erfassen;
das ist keine Mindesthardwarefestlegung.

## Nächste Arbeitsrunde

`python3 tools/work_packet.py list` enthält ausschließlich neue abgegrenzte
Folgevorschläge und die offene Ziel-PC-Abnahme. Alte Pakete für Rüssel, Editor,
Manifest, Begegnungen, Zweitort und erste Terrainpublikation nicht nochmals starten.
Der Katalog reserviert keine Arbeit; die Belegung führt der Integrationschat.

[Folgearbeiten](NEXT_PARALLEL_WORK.md) · [Arbeitsablauf](PARALLEL_WORKFLOW.md) ·
[Technische Richtung](GODOT_TECHNICAL_DIRECTION.md) · [Roadmap](../ROADMAP.md).
